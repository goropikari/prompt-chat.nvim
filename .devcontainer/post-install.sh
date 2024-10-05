#!/binrbash

cargo install typos-cli
cargo install stylua
mkdir -p ~/.config
ln -s /workspaces/prompt-chat.nvim/.devcontainer/nvim ~/.config/nvim
