# Rastreando uma alteração que "sumiu" do branch

Passo a passo para descobrir onde está um ajuste que você já fez e por que ele não aparece no branch atual. As causas mais comuns são: faltou mergear o branch, o código se perdeu num conflito ou alguém reverteu a mudança.

> Exemplo real usado aqui: o ajuste para aceitar `ISENTO` nas inscrições estadual e municipal (bop-portal-web) não aparecia no `feat/multi-companies-pre-order`.

## 1. Achar o commit

```bash
git log --all --oneline -i --grep="isento"   # pela mensagem do commit
git log --all --oneline -S "ISENTO"          # pelo conteúdo do código (pickaxe)
grep -rn -i "isento" apps/frontend/src       # o código atual tem a string?
```

- `--all` procura em todos os branches, locais e remotos. Sem ele, só entra o histórico do branch atual.
- `-S "texto"` acha commits que mudaram a quantidade de ocorrências do texto. Funciona mesmo quando a mensagem do commit não cita a palavra.

Resultado: `bb43e0d5 feat: adjusting field to accept ISENTO`, mais alguns commits relacionados.

## 2. Ver em quais branches o commit está

```bash
git log -1 --format='%h %an %ad %s' --date=iso bb43e0d5
git show --stat bb43e0d5
git branch -a --contains bb43e0d5
git merge-base --is-ancestor bb43e0d5 HEAD && echo sim || echo nao
```

- `git branch -a --contains` responde **quais branches têm esse commit**. Aqui: `feat/BPP-305` e `origin/feat/multi-companies-onboarding`.
- `git merge-base --is-ancestor A B` responde **se A faz parte do histórico de B**. Aqui: não.

Esse resultado separa as duas hipóteses:

| Commit no histórico de HEAD? | O que aconteceu | Próximo passo |
|---|---|---|
| **Sim**, mas o código sumiu | Conflito mal resolvido ou reversão | `git log -S "trecho" HEAD` para achar quem removeu |
| **Não** | Faltou mergear o branch | Seguir para o passo 3 |

## 3. Descobrir por que não chegou

Primeiro, a situação dos branches envolvidos:

```bash
git fetch --all
git log -1 --format='%h %ad %s' --date=short origin/feat/multi-companies-onboarding
git merge-base --is-ancestor origin/feat/multi-companies-onboarding origin/develop && echo sim || echo nao
```

Deu não: o branch com o ajuste ainda não tinha ido para o `develop`. Por isso o merge do `develop` não trouxe nada.

Depois, se o branch já tinha entrado por outro caminho, olhando quem mexeu por último num arquivo do ajuste:

```bash
git log --oneline -3 HEAD -- apps/frontend/src/utils/masks.ts
# 5059d083 Merge branch 'feat/BPP-305' into feat/BPP-26
```

O `BPP-305` tinha sido mergeado. Faltava saber **qual versão** dele entrou:

```bash
git log -1 --format='%h %ad %P %s' --date=iso 5059d083   # %P lista os pais do merge
git log -1 --format='%h %ad %s' --date=iso 5059d083^2    # 2º pai = o branch que foi mergeado
```

Todo merge tem dois pais:

- **`^1`**: o branch que recebeu o merge
- **`^2`**: o branch que foi mergeado

O `^2` apontou para um commit de 20/09 às 15:09. O ajuste do `ISENTO` é de 21/09, então veio depois do merge.

## 4. Listar o que ficou de fora

```bash
git log --oneline --format='%h %ad %s' --date=short HEAD..origin/feat/BPP-305
```

`A..B` lista os commits que estão em B e não estão em A. A lista trouxe todo o trabalho feito no `BPP-305` depois do merge de 20/09.

## 5. Confirmar no código

```bash
git show bb43e0d5 -- apps/frontend/src/utils/masks.ts   # diff do commit, só nesse arquivo
grep -n -i "isento\|exempt" apps/frontend/src/utils/masks.ts
```

O código atual ainda tinha o checkbox `stateMunicipalRegistrationExempt`, que um commit posterior do `BPP-305` removeu. Isso confirma que o branch estava com uma versão antiga do `BPP-305`.

## Conclusão do exemplo

O código não se perdeu num conflito. O `BPP-305` foi mergeado no `BPP-26` **antes** do ajuste do `ISENTO` e nunca mais foi mergeado de novo. O ajuste seguiu pelo `feat/multi-companies-onboarding`, que ainda não tinha chegado ao `develop`.

Solução: mergear `origin/feat/multi-companies-onboarding` no branch atual. Cherry-pick de commits soltos não é uma boa opção, porque os commits dependem uns dos outros.

## Roteiro rápido

1. `git log --all -S "trecho"` ou `git log --all -i --grep="palavra"`: achar o commit
2. `git branch -a --contains <hash>`: onde ele está
3. `git merge-base --is-ancestor <hash> HEAD`: está no meu branch?
   - **Sim, mas sumiu:** conflito ou reversão. Rode `git log -S "trecho" HEAD`.
   - **Não:** faltou merge. Siga para o passo 4.
4. `git log --oneline HEAD -- <arquivo>` e `git log -1 <merge>^2`: por qual caminho deveria ter vindo e qual versão entrou
5. `git log --oneline HEAD..origin/<branch>`: o que ainda falta

Dica: `git log --graph --oneline --all -- <arquivo>` desenha o grafo dos branches só para aquele arquivo.

Os comandos estão no cheat `git-rastrear.cheat`.
