# dev-notes

Comandos e anotações do dia a dia, prontos para buscar e executar no terminal com o [navi](https://github.com/denisidoro/navi).

## Conteúdo

- `cheats/`: cheatsheets do navi. Cada comando tem uma descrição e, quando precisa, placeholders (`<arquivo>`, `<branch>`) que o navi pergunta na hora.
  - `git-dia-a-dia.cheat`: commits, branches, stash, comparações, reflog, worktrees
  - `git-merge.cheat`: investigar e resolver conflitos de merge
  - `git-rastrear.cheat`: achar um commit, em quais branches ele está e por que não chegou ao branch atual
  - `busca-texto.cheat`: grep, ripgrep, sed, awk, sort/uniq, jq
  - `arquivos.cheat`: links simbólicos, find, ls, cp/mv/rm, du/df, tar/zip, permissões
  - `sistema-rede.cheat`: portas e processos, variáveis de ambiente, curl, dig, utilitários do macOS
  - `node-pnpm.cheat`: pnpm em monorepo, vitest, nvm
- `notes/`: explicações e passo a passo em Markdown.
  - `git/investigar-conflitos-de-merge.md`
  - `git/rastrear-alteracao-que-nao-chegou.md`
- `install.sh`: instala as dependências e configura o navi no shell.

## Instalação

Requisitos: macOS ou Linux (Debian/Ubuntu, Fedora ou Arch), com `git`, `curl` e acesso a `sudo` no Linux. O shell pode ser zsh ou bash.

```bash
git clone git@github.com:gu1ma/dev-notes.git ~/dev-notes
cd ~/dev-notes
./install.sh
```

Depois abra um novo terminal (ou rode `source ~/.zshrc`).

O script pode ser rodado de novo sem problema: o que já está instalado é mantido.

### O que o script faz

1. **Instala os pacotes**:
   - macOS: instala o Homebrew, se faltar, e depois `navi`, `fzf`, `ripgrep` e `jq`. `git`, `curl` e `dig` já vêm no sistema.
   - Linux: `git`, `curl`, `fzf`, `ripgrep`, `jq` e `dig` pelo `apt`, `dnf` ou `pacman`. O `navi` vem pelo `pacman` ou, nas outras distros, pelo instalador oficial em `~/.local/bin`.
2. **Instala o Node**: `nvm`, a versão LTS do Node (definida como padrão) e o `pnpm`. Para pular esta etapa, rode `./install.sh --skip-node`.
3. **Configura o shell**: adiciona ao `~/.zshrc` (ou `~/.bashrc`, ou `~/.bash_profile` no macOS) um bloco entre `# >>> dev-notes >>>` e `# <<< dev-notes <<<` com:
   - `NAVI_PATH` apontando para a pasta `cheats/` deste repositório, onde quer que ele esteja clonado;
   - o widget do navi (atalho **Ctrl+G**);
   - o carregamento do `nvm`.

   Se o repositório mudar de pasta, rode o script de novo para atualizar o caminho. Se o rc já tinha a configuração manual antiga do navi, ela é removida e um backup fica em `<rc>.dev-notes.bak`.

### Instalação manual

Se preferir não usar o script (exemplo no macOS com zsh):

```bash
brew install navi fzf ripgrep jq
echo 'export NAVI_PATH="$HOME/dev-notes/cheats"' >> ~/.zshrc
echo 'eval "$(navi widget zsh)"' >> ~/.zshrc
source ~/.zshrc
```

Ajuste `$HOME/dev-notes` para a pasta onde o repositório foi clonado.

## Uso

- **Ctrl+G** em qualquer terminal: abre a busca. Digite parte da descrição ou do comando, escolha com Enter e preencha os placeholders. O comando vai para a linha de comando para você revisar antes de rodar.
- `navi`: mesma busca, executando o comando escolhido.
- `navi --query "stash"`: abre a busca já filtrada.

## Adicionar comandos

Os arquivos `.cheat` seguem o formato do navi:

```
% git, dia a dia

# Descrição que aparece na busca
git log --oneline --author="<autor>"

$ autor: git log --format='%an' | sort -u
```

- `% tags`: primeira linha do arquivo; agrupa os comandos na busca.
- `# descrição`: a linha logo acima do comando.
- `<nome>`: placeholder preenchido na hora.
- `$ nome: comando`: sugestões para o placeholder, geradas por um comando.

Não é preciso reiniciar nada: o navi lê os arquivos a cada busca.

## Observações

- Alguns comandos de `sistema-rede.cheat` são só do macOS: `pbpaste`, `open`, `caffeinate` e `xattr`.
