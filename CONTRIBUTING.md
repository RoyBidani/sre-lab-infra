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
