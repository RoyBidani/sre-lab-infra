#!/bin/bash

# GitHub Upload Script for SRE Lab Infrastructure
# Creates repository and pushes all code to GitHub

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}==== $1 ====${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

show_usage() {
    cat << EOF
🚀 GitHub Upload Script for SRE Lab Infrastructure

Usage: $0 [REPO_NAME] [OPTIONS]

ARGUMENTS:
    REPO_NAME       Name for the GitHub repository (default: sre-lab-infra)

OPTIONS:
    --private       Create private repository
    --public        Create public repository (default)
    --description   Repository description
    --force         Force push (overwrite existing repository)
    --dry-run       Show what would be done without executing

EXAMPLES:
    $0 my-sre-lab
    $0 sre-training-environment --private
    $0 sre-lab-infra --description "Production-grade SRE training environment"
    $0 --dry-run

PREREQUISITES:
    - GitHub CLI (gh) installed and authenticated
    - Git configured with your name and email

EOF
}

check_prerequisites() {
    print_header "Prerequisites Check"
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed"
        exit 1
    fi
    
    # Check if GitHub CLI is installed
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed"
        print_error "Install it with: curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg"
        print_error "And: echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null"
        print_error "Then: sudo apt update && sudo apt install gh"
        exit 1
    fi
    
    # Check if GitHub CLI is authenticated
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated"
        print_error "Run: gh auth login"
        exit 1
    fi
    
    # Check git configuration
    if ! git config user.name &> /dev/null || ! git config user.email &> /dev/null; then
        print_warning "Git user configuration missing"
        print_warning "Please configure git:"
        print_warning "git config --global user.name \"Your Name\""
        print_warning "git config --global user.email \"your.email@example.com\""
        
        read -p "Configure git now? (y/N): " configure_git
        if [[ "$configure_git" =~ ^[Yy]$ ]]; then
            read -p "Enter your name: " git_name
            read -p "Enter your email: " git_email
            git config --global user.name "$git_name"
            git config --global user.email "$git_email"
            print_status "✅ Git configured successfully"
        else
            exit 1
        fi
    fi
    
    # Get GitHub username
    GITHUB_USERNAME=$(gh api user --jq .login)
    print_status "✅ Authenticated as: $GITHUB_USERNAME"
    print_status "✅ All prerequisites met"
}

create_gitignore() {
    print_step "Creating .gitignore file..."
    
    cat > .gitignore << 'EOF'
# Terraform
*.tfstate
*.tfstate.*
*.tfvars
.terraform/
.terraform.lock.hcl
terraform.tfplan
terraform.tfplan.*

# Kubernetes secrets (if any)
*-secret.yaml
secrets/

# Backup files
config-backups/
*.backup
*.bak

# Logs
*.log
logs/

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Temporary files
tmp/
temp/
*.tmp

# Claude settings (keep local only)
.claude/

# Environment files
.env
.env.local
.env.*.local

EOF

    print_status "✅ .gitignore created"
}

create_contributing_guide() {
    print_step "Creating CONTRIBUTING.md guide..."
    
    cat > CONTRIBUTING.md << 'EOF'
# Contributing to SRE Lab Infrastructure

Thank you for your interest in contributing to this SRE training environment! 🚀

## Ways to Contribute

### 1. Bug Reports
- Use the bug report template when creating issues
- Include detailed steps to reproduce
- Provide environment information (OS, tool versions)
- Include error messages and logs

### 2. Feature Requests
- Use the feature request template
- Explain the use case and benefit
- Consider backward compatibility

### 3. Documentation Improvements
- Fix typos or unclear instructions
- Add examples or clarifications
- Update outdated information

### 4. Code Contributions
- Follow existing code style and patterns
- Test your changes thoroughly
- Update documentation as needed

## Development Workflow

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes**
4. **Test thoroughly**:
   ```bash
   # Validate Terraform
   cd terraform && terraform validate
   
   # Validate Kubernetes YAML
   find k8s-manifests -name "*.yaml" | xargs kubectl --dry-run=client apply -f
   
   # Test scripts
   ./scripts/verify-setup.sh --check-only
   ```
5. **Commit with descriptive messages**
6. **Push to your fork**: `git push origin feature/your-feature-name`
7. **Create a Pull Request**

## Code Standards

### Terraform
- Use consistent formatting: `terraform fmt`
- Follow naming conventions (kebab-case for resources)
- Include comments for complex logic
- Use variables for configurable values

### Kubernetes YAML
- Use consistent indentation (2 spaces)
- Include resource limits and requests
- Add labels for organization
- Include health checks where appropriate

### Shell Scripts
- Use `#!/bin/bash` and `set -e`
- Include error handling
- Add usage documentation
- Make scripts executable: `chmod +x`

### Documentation
- Use clear, concise language
- Include code examples
- Explain the "why" not just the "what"
- Keep guides up to date

## Testing Guidelines

### Local Testing
- Test on clean environment when possible
- Verify all scripts work end-to-end
- Check documentation accuracy
- Test with different configurations

### Infrastructure Testing
- Always use `terraform plan` before `apply`
- Test in non-production AWS account
- Verify resource cleanup works
- Monitor costs during testing

## Community Guidelines

- Be respectful and inclusive
- Help others learn and improve
- Share knowledge and experiences
- Focus on constructive feedback

## Questions?

- Create an issue for general questions
- Use discussions for brainstorming
- Check existing issues before creating new ones

## Recognition

Contributors will be recognized in:
- README.md acknowledgments
- Release notes for significant contributions
- Community showcases

Thank you for helping make SRE education more accessible! 🎓
EOF

    print_status "✅ CONTRIBUTING.md created"
}

create_issue_templates() {
    print_step "Creating GitHub issue templates..."
    
    mkdir -p .github/ISSUE_TEMPLATE
    
    # Bug report template
    cat > .github/ISSUE_TEMPLATE/bug_report.md << 'EOF'
---
name: Bug report
about: Create a report to help us improve the SRE lab infrastructure
title: "[BUG] "
labels: bug
assignees: ''
---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Run command '...'
2. See error

**Expected behavior**
A clear and concise description of what you expected to happen.

**Environment:**
- OS: [e.g. Ubuntu 22.04]
- Terraform version: [e.g. 1.5.0]
- kubectl version: [e.g. 1.28.0]
- AWS CLI version: [e.g. 2.13.0]

**Error Output**
```
Paste error output here
```

**Additional context**
Add any other context about the problem here.
EOF

    # Feature request template
    cat > .github/ISSUE_TEMPLATE/feature_request.md << 'EOF'
---
name: Feature request
about: Suggest an idea for the SRE lab infrastructure
title: "[FEATURE] "
labels: enhancement
assignees: ''
---

**Is your feature request related to a problem? Please describe.**
A clear and concise description of what the problem is.

**Describe the solution you'd like**
A clear and concise description of what you want to happen.

**Describe alternatives you've considered**
A clear and concise description of any alternative solutions or features you've considered.

**Additional context**
Add any other context or screenshots about the feature request here.
EOF

    # Setup help template
    cat > .github/ISSUE_TEMPLATE/setup_help.md << 'EOF'
---
name: Setup Help
about: Get help with setting up the SRE lab environment
title: "[HELP] "
labels: help wanted
assignees: ''
---

**What are you trying to do?**
Describe what you're trying to accomplish.

**What step are you on?**
- [ ] Prerequisites installation
- [ ] Terraform infrastructure deployment
- [ ] Application deployment
- [ ] Monitoring setup
- [ ] SRE practices implementation
- [ ] Other: ___________

**What have you tried?**
List the commands you've run and any troubleshooting steps you've taken.

**Error messages or output:**
```
Paste any relevant output here
```

**Your environment:**
- Operating System:
- AWS Region:
- Have you followed the README step by step? (yes/no)
EOF

    print_status "✅ Issue templates created"
}

create_pull_request_template() {
    print_step "Creating pull request template..."
    
    mkdir -p .github
    
    cat > .github/pull_request_template.md << 'EOF'
## Description
Brief description of the changes in this pull request.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Infrastructure change
- [ ] Configuration update

## Testing
- [ ] I have tested these changes locally
- [ ] I have run the verification scripts
- [ ] I have updated documentation as needed
- [ ] I have added/updated tests as needed

## Checklist
- [ ] My code follows the existing style
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] My changes generate no new warnings
- [ ] Any dependent changes have been merged and published

## Screenshots (if applicable)
Add screenshots to help explain your changes.

## Additional Notes
Any additional information that reviewers should know.
EOF

    print_status "✅ Pull request template created"
}

create_example_tfvars() {
    print_step "Creating example Terraform variables file..."
    
    cat > terraform/terraform.tfvars.example << 'EOF'
# AWS Configuration
aws_region = "eu-central-1"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
public_subnets = ["10.0.1.0/24", "10.0.3.0/24"]
private_subnets = ["10.0.2.0/24", "10.0.4.0/24"]

# EKS Configuration
cluster_name = "sre-lab-eks"
cluster_version = "1.28"

# Node Group Configuration
node_instance_types = ["t3.medium"]
node_desired_size = 2
node_max_size = 4
node_min_size = 1

# Tags
common_tags = {
  Project     = "SRE-Lab"
  Environment = "training"
  Owner       = "your-name"
  CreatedBy   = "terraform"
}
EOF

    print_status "✅ Example tfvars file created"
}

prepare_repository() {
    print_header "Preparing Repository"
    
    # Clean up any existing git repo
    if [ -d .git ]; then
        print_warning "Existing git repository found. Removing..."
        rm -rf .git
    fi
    
    # Initialize git repository
    print_step "Initializing git repository..."
    git init
    git branch -M main
    
    # Create necessary files
    create_gitignore
    create_contributing_guide
    create_issue_templates
    create_pull_request_template
    create_example_tfvars
    
    # Add all files
    print_step "Adding files to git..."
    git add .
    
    # Initial commit
    print_step "Creating initial commit..."
    git commit -m "🚀 Initial commit: Complete SRE Training Environment

✅ Infrastructure as Code with Terraform (AWS EKS)
✅ 3-tier microservices application (Frontend, Backend, Database)
✅ Comprehensive monitoring stack (Prometheus, Grafana)
✅ Advanced SRE practices (SLO monitoring, Alerting, Chaos Engineering)
✅ Zero-downtime deployment scripts
✅ Production-grade security and networking
✅ Complete documentation and guides
✅ Automated testing and validation

🎯 Production-ready SRE training environment for hands-on learning!

🤖 Generated with Claude Code (https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
    
    print_status "✅ Repository prepared"
}

create_github_repository() {
    local repo_name=$1
    local visibility=$2
    local description=$3
    local dry_run=$4
    
    print_header "Creating GitHub Repository"
    
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would create repository '$repo_name' ($visibility)"
        print_status "DRY RUN: Would push to GitHub"
        return 0
    fi
    
    # Check if repository already exists
    if gh repo view "$GITHUB_USERNAME/$repo_name" &> /dev/null; then
        if [ "$FORCE" = "true" ]; then
            print_warning "Repository exists. Force flag set, continuing..."
        else
            print_warning "Repository '$repo_name' already exists"
            read -p "Continue and update existing repository? (y/N): " continue_update
            if [[ ! "$continue_update" =~ ^[Yy]$ ]]; then
                print_status "Upload cancelled"
                exit 0
            fi
        fi
        
        # Add remote if it doesn't exist
        if ! git remote get-url origin &> /dev/null; then
            git remote add origin "https://github.com/$GITHUB_USERNAME/$repo_name.git"
        fi
    else
        # Create new repository
        print_step "Creating new GitHub repository..."
        gh repo create "$repo_name" \
            --$visibility \
            --description "$description" \
            --clone=false \
            --add-readme=false
        
        # Add remote
        git remote add origin "https://github.com/$GITHUB_USERNAME/$repo_name.git"
        print_status "✅ Repository created: https://github.com/$GITHUB_USERNAME/$repo_name"
    fi
    
    # Push to GitHub
    print_step "Pushing to GitHub..."
    if [ "$FORCE" = "true" ]; then
        git push -f origin main
    else
        git push -u origin main
    fi
    
    print_status "✅ Code pushed to GitHub successfully"
}

setup_repository_settings() {
    local repo_name=$1
    local dry_run=$2
    
    print_header "Configuring Repository Settings"
    
    if [ "$dry_run" = "true" ]; then
        print_status "DRY RUN: Would configure repository settings"
        return 0
    fi
    
    # Enable GitHub Pages (if public repository)
    if [ "$VISIBILITY" = "public" ]; then
        print_step "Configuring GitHub Pages..."
        gh api -X PATCH "/repos/$GITHUB_USERNAME/$repo_name" \
            --field has_pages=true \
            --silent || print_warning "Could not enable GitHub Pages"
    fi
    
    # Set repository topics
    print_step "Setting repository topics..."
    gh api -X PUT "/repos/$GITHUB_USERNAME/$repo_name/topics" \
        --field names='["sre","kubernetes","terraform","aws","prometheus","grafana","chaos-engineering","monitoring","devops","training"]' \
        --silent || print_warning "Could not set topics"
    
    print_status "✅ Repository settings configured"
}

generate_summary() {
    local repo_name=$1
    
    print_header "Upload Complete! 🎉"
    
    cat << EOF

📊 Repository Summary:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔗 Repository URL: https://github.com/$GITHUB_USERNAME/$repo_name
🌟 Visibility: $VISIBILITY
👤 Owner: $GITHUB_USERNAME

📁 What's Included:
✅ Complete Terraform infrastructure (AWS EKS)
✅ 3-tier microservices application
✅ Prometheus + Grafana monitoring stack
✅ SLO monitoring, alerting, and chaos engineering
✅ Zero-downtime deployment scripts
✅ Comprehensive documentation
✅ Contributing guidelines
✅ Issue and PR templates

🚀 Next Steps:
1. Clone the repository: git clone https://github.com/$GITHUB_USERNAME/$repo_name.git
2. Follow the README.md for setup instructions
3. Customize terraform/terraform.tfvars based on terraform.tfvars.example
4. Share with your team or community!

🎯 Perfect for:
• SRE training and education
• Kubernetes learning
• Production-grade infrastructure examples
• Team onboarding
• Interview preparation

Happy learning! 🚀

EOF
}

# Parse command line arguments
REPO_NAME="sre-lab-infra"
VISIBILITY="public"
DESCRIPTION="🚀 Complete SRE Training Environment - Production-grade infrastructure with Kubernetes, Prometheus, Grafana, and advanced SRE practices for hands-on learning"
FORCE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --private)
            VISIBILITY="private"
            shift
            ;;
        --public)
            VISIBILITY="public"
            shift
            ;;
        --description)
            DESCRIPTION="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            REPO_NAME="$1"
            shift
            ;;
    esac
done

# Main execution
print_header "GitHub Upload - SRE Lab Infrastructure"
echo "Repository: $REPO_NAME"
echo "Visibility: $VISIBILITY"
echo "Description: $DESCRIPTION"
echo

check_prerequisites
prepare_repository
create_github_repository "$REPO_NAME" "$VISIBILITY" "$DESCRIPTION" "$DRY_RUN"
setup_repository_settings "$REPO_NAME" "$DRY_RUN"

if [ "$DRY_RUN" != "true" ]; then
    generate_summary "$REPO_NAME"
else
    print_warning "This was a DRY RUN - no actual changes were made"
fi