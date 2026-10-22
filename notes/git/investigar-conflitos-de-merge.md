# Investigando conflitos de merge manualmente

Passo a passo para entender **por que** um trecho está em conflito: quem mudou o quê, em qual commit e com qual intenção.

> Exemplo real usado aqui: merge do `develop` dentro do `feat/multi-companies-pre-order` (bop-portal-web), com conflito em `useBulkRegisterActions.ts`. O `develop` trocou `isInvalidColumnsDialogOpen` por `rejectionDialogReason`, e o branch de feature adicionou `templateVariant`.

## 1. Entender o que está sendo mergeado

```bash
cat .git/MERGE_MSG               # "Merge branch 'develop' into feat/multi-companies-pre-order"
git merge-base HEAD MERGE_HEAD   # ancestral comum dos dois lados (ex.: 13050fcd)
```

Durante um merge você tem três referências:

- **`HEAD`**: o seu branch (lado `<<<<<<< HEAD` do conflito)
- **`MERGE_HEAD`**: o que está entrando (lado `>>>>>>> develop`)
- **merge-base**: o ponto em que os dois lados se separaram

## 2. Ver as três versões do arquivo

O Git guarda cada versão do arquivo em conflito num "stage":

```bash
F=caminho/do/arquivo.ts
git show :1:$F   # base (antes dos dois lados mexerem)
git show :2:$F   # ours   → seu branch
git show :3:$F   # theirs → branch que está entrando
```

Para ver a base **dentro** do próprio conflito:

```bash
git checkout --conflict=diff3 -- $F
```

Isso acrescenta um bloco `||||||| base` entre os marcadores e mostra como o trecho era antes. Com ele fica claro quem adicionou e quem removeu cada coisa.

> ⚠️ Esse comando descarta o que você já resolveu nesse arquivo.

Para deixar sempre ligado:

```bash
git config --global merge.conflictStyle zdiff3
```

## 3. Achar quais commits mexeram no arquivo em cada lado

```bash
git log --oneline --left-right HEAD...MERGE_HEAD -- $F
```

```
> d6727a8e fix: open modal with empty spreadsheet                               ← develop
< efe29a1a feat(employees): adapt bulk spreadsheet upload ... [BPP-594]          ← seu branch
```

Os três pontos (`...`) mostram só os commits que existem de um lado e não do outro, a partir do merge-base. O `<` marca os commits do seu lado e o `>` os do outro lado.

## 4. Achar o commit que introduziu ou removeu um identificador

O "pickaxe" (`-S`) procura commits que mudaram a quantidade de ocorrências de uma string:

```bash
git log -S rejectionDialogReason --oneline MERGE_HEAD -- apps/frontend/src
# d6727a8e fix: open modal with empty spreadsheet

git log -S templateVariant --oneline HEAD -- $F
# efe29a1a feat(employees): adapt bulk spreadsheet upload ... [BPP-594]
```

Variações úteis:

- `git log -G 'isInvalidColumns\w*'` aceita regex
- `git log -S X --all` procura em todos os branches

## 5. Ler o commit para entender o refactor

```bash
git show --stat <hash>     # quais arquivos o commit tocou
git show <hash> -- $F      # diff só deste arquivo
git show <hash> -M         # detecta renames (ex.: InvalidColumnsDialog → RejectionDialog)
```

Faça isso para o commit de cada lado. Assim você entende a intenção de cada mudança.

## 6. Comparar cada lado com a base (visão geral)

```bash
git diff $(git merge-base HEAD MERGE_HEAD) HEAD -- $F        # o que o seu branch mudou
git diff $(git merge-base HEAD MERGE_HEAD) MERGE_HEAD -- $F  # o que o outro lado mudou
```

Regra de resolução: **manter o que cada lado adicionou de propósito**. O que um lado **substituiu** deve sair.

No exemplo: mantém `templateVariant` (feature) e `rejectionDialogReason` (develop). Sai `isInvalidColumnsDialogOpen`, que foi substituído no develop.

## 7. Confirmar que não sobrou referência antiga

```bash
git grep -n "nomeAntigo" -- apps/frontend/src              # working tree
git grep -n "nomeAntigo" MERGE_HEAD -- apps/frontend/src   # no outro lado
```

Se o nome não existe no outro lado e o working tree só o usa no bloco em conflito, ele é resto do lado antigo.

Depois de resolver, rode o typecheck ou lint do projeto para validar.

## Extras

- **`git blame $F`** (ou `git blame MERGE_HEAD -- $F`) mostra o commit de cada linha.
- **`git log -L '/regex/,+2:'$F MERGE_HEAD`** mostra a história de um trecho específico.
- **No VS Code:** o merge editor (botão "Resolve in Merge Editor") mostra Incoming, Current e Result lado a lado. O GitLens tem blame inline e o histórico do arquivo.
- **No Azure DevOps:** com o hash do commit, abra o commit para chegar ao PR que o trouxe e ler a descrição ou o ticket.
