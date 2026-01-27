# Contributing to Log Service Platform

Thank you for your interest in contributing to the Log Service Platform! This document provides guidelines and instructions for contributing to this project.

## Table of Contents
1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [Making Changes](#making-changes)
5. [Testing Guidelines](#testing-guidelines)
6. [Submitting Changes](#submitting-changes)
7. [Code Style Guidelines](#code-style-guidelines)

## Code of Conduct

This project adheres to professional standards of collaboration:

- Be respectful and constructive in all interactions
- Welcome diverse perspectives and ideas
- Focus on what is best for the project and community
- Show empathy towards other contributors

## Getting Started

### Prerequisites for Development

- Python 3.12+
- Terraform 1.6.0+
- AWS CLI
- Git
- Text editor or IDE (VS Code, PyCharm recommended)

### Setting Up Development Environment

```bash
# Clone the repository
git clone https://github.com/yourusername/log-service-platform.git
cd log-service-platform

# Create Python virtual environment (for local testing)
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install development dependencies
pip install boto3 pytest pytest-cov black flake8
```

## Development Setup

### Local Testing Setup

For local Lambda testing, you can use AWS SAM or Docker:

```bash
# Install AWS SAM CLI
pip install aws-sam-cli

# Test locally
sam local invoke IngestFunction -e test_events/ingest_event.json
```

### Setting Up Test AWS Account

It's recommended to use a separate AWS account for development:

```bash
# Configure separate AWS profile
aws configure --profile log-service-dev

# Use profile with Terraform
export AWS_PROFILE=log-service-dev
```

## Making Changes

### Branch Naming Convention

```
feature/description    # New features
bugfix/description     # Bug fixes
hotfix/description     # Urgent fixes
docs/description       # Documentation updates
refactor/description   # Code refactoring
```

Example:
```bash
git checkout -b feature/add-log-filtering
```

### Commit Message Guidelines

Follow conventional commits:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Example:**
```
feat(lambda): add log filtering by severity level

Implement filtering capability in ReadRecent Lambda to allow
clients to request logs of specific severity levels.

Closes #123
```

## Testing Guidelines

### Running Tests

```bash
# Unit tests (when implemented)
pytest tests/unit/

# Integration tests
./tests/test_ingest.sh $INGEST_URL
./tests/test_read_recent.sh $READ_RECENT_URL
```

### Writing Tests

When adding new features, include tests:

**Lambda Function Test:**
```python
# tests/unit/test_ingest_lambda.py
import json
from lambdas.ingest.lambda_function import lambda_handler, validate_log_entry

def test_validate_log_entry_valid():
    body = {"severity": "info", "message": "Test message"}
    assert validate_log_entry(body) is None

def test_validate_log_entry_invalid_severity():
    body = {"severity": "critical", "message": "Test"}
    error = validate_log_entry(body)
    assert "Invalid severity" in error
```

**Infrastructure Test:**
```bash
# Test Terraform configuration
cd infrastructure
terraform validate
terraform fmt -check
```

### Test Coverage Requirements

- All new Lambda functions should have unit tests
- Integration tests should cover happy path and error cases
- Aim for >80% code coverage

## Submitting Changes

### Pull Request Process

1. **Update your fork:**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Create a pull request:**
   - Use a clear, descriptive title
   - Reference any related issues
   - Include test results
   - Update documentation as needed

3. **Pull Request Template:**
   ```markdown
   ## Description
   Brief description of changes
   
   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update
   
   ## Testing
   - [ ] Unit tests pass
   - [ ] Integration tests pass
   - [ ] Manual testing completed
   
   ## Checklist
   - [ ] Code follows style guidelines
   - [ ] Documentation updated
   - [ ] Tests added/updated
   - [ ] No breaking changes (or documented if yes)
   ```

4. **Review Process:**
   - At least one approval required
   - All CI checks must pass
   - No unresolved comments

## Code Style Guidelines

### Python Style (PEP 8)

```python
# Use black for formatting
black lambdas/

# Use flake8 for linting
flake8 lambdas/
```

**Key Guidelines:**
- 4 spaces for indentation
- Max line length: 88 characters (black default)
- Use docstrings for functions
- Type hints where appropriate

**Example:**
```python
def validate_log_entry(body: dict) -> Optional[str]:
    """
    Validate the log entry payload.
    
    Args:
        body: Dictionary containing log entry data
        
    Returns:
        Error message if invalid, None if valid
    """
    if 'severity' not in body:
        return 'Missing required field: severity'
    
    return None
```

### Terraform Style

```bash
# Format Terraform files
terraform fmt -recursive infrastructure/
```

**Key Guidelines:**
- Use snake_case for resource names
- Add descriptions to all variables
- Use consistent tagging
- Group related resources

**Example:**
```hcl
resource "aws_lambda_function" "ingest" {
  function_name = "${var.project_name}-${var.environment}-ingest"
  runtime       = "python3.12"
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-ingest"
    Component   = "ingest"
    Environment = var.environment
  }
}
```

### Documentation Style

- Use Markdown for all documentation
- Keep line length reasonable (80-100 chars)
- Include code examples where helpful
- Keep TOC updated

## Infrastructure Changes

### When Making Infrastructure Changes

1. **Test in development environment first**
2. **Run terraform plan and review**
3. **Document any new outputs or variables**
4. **Update README if user-facing changes**

### Adding New Resources

**Template for new resources:**

```hcl
# Description of what this resource does
resource "aws_service_resource" "name" {
  # Required parameters
  name = "${var.project_name}-${var.environment}-resource-name"
  
  # Optional parameters
  setting = var.setting_value
  
  # Tags
  tags = {
    Name        = "${var.project_name}-${var.environment}-resource-name"
    Component   = "component-name"
    Environment = var.environment
  }
}
```

## Lambda Changes

### Adding New Lambda Functions

1. Create function directory: `lambdas/new_function/`
2. Add `lambda_function.py` with handler
3. Add `requirements.txt`
4. Add Terraform resource in `main.tf`
5. Add outputs in `outputs.tf`
6. Update README with new functionality
7. Add tests

### Lambda Best Practices

- Keep functions small and focused
- Use environment variables for configuration
- Include proper error handling
- Log important events
- Return consistent response format

## Performance Considerations

### DynamoDB

- Avoid scans, use queries with GSI
- Monitor consumed capacity
- Consider batch operations for bulk inserts

### Lambda

- Minimize cold start time
- Reuse connections (DynamoDB client)
- Use appropriate memory allocation
- Set reasonable timeout values

## Security Considerations

### Required Security Practices

- Never commit AWS credentials
- Use least-privilege IAM policies
- Enable encryption at rest and in transit
- Validate all input data
- Sanitize log output (no sensitive data)

### Security Review Checklist

- [ ] No hardcoded secrets
- [ ] Input validation implemented
- [ ] Appropriate IAM permissions
- [ ] Encryption enabled
- [ ] Error messages don't leak sensitive data

## Documentation

### What to Document

- New features and their usage
- API changes
- Configuration options
- Breaking changes
- Migration guides (if applicable)

### Where to Document

- `README.md`: User-facing features, setup, usage
- `ARCHITECTURE.md`: Design decisions, diagrams
- `DEPLOYMENT.md`: Deployment instructions
- Code comments: Complex logic, non-obvious decisions

## Getting Help

### Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [DynamoDB Best Practices](https://docs.aws.amazon.com/dynamodb/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)

### Communication

- Open an issue for bugs or feature requests
- Use discussions for questions
- Tag maintainers for urgent issues

## Recognition

Contributors will be recognized in:
- GitHub contributors list
- Release notes (for significant contributions)
- CONTRIBUTORS.md file (if maintained)

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

Thank you for contributing to the Log Service Platform!
