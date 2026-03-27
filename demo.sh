docker run -it -e GITHUB_TOKEN=$(gh auth token) ubuntu:24.04 bash -c 'apt-get update && apt-get install -y curl git sudo && mkdir -p ~/.config/chezmoi && cat > ~/.config/chezmoi/chezmoi.toml <<EOF
[data]
    git_name = "Your Name"
    git_email = "yourname@example.com"
EOF
GITHUB_TOKEN=$GITHUB_TOKEN curl -fsLS https://raw.githubusercontent.com/mmcardle/setmeup/main/bootstrap.sh | sh; exec bash'
