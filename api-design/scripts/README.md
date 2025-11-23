# Automation Scripts Directory

## Purpose
This directory contains scripts for automating the API design, data modeling, and taxonomy management workflow.

## Available Scripts

### 1. Model Generation Scripts
- `generate_openapi.py`: Generate OpenAPI specs from data models
- `generate_json_schema.py`: Generate JSON schemas from taxonomy
- `generate_graphql.py`: Generate GraphQL schemas from models
- `validate_models.py`: Validate data model completeness

### 2. Taxonomy Scripts
- `validate_taxonomy.py`: Check taxonomy compliance
- `update_taxonomy.py`: Update taxonomy classifications
- `audit_taxonomy.py`: Generate taxonomy compliance reports

### 3. Schema Validation Scripts
- `validate_openapi.py`: Validate OpenAPI specifications
- `validate_json_schema.py`: Validate JSON schemas
- `check_breaking_changes.py`: Detect breaking API changes

### 4. Documentation Scripts
- `generate_docs.py`: Generate API documentation
- `generate_diagrams.py`: Generate ER diagrams from models
- `update_wiki.py`: Update Azure DevOps wiki

### 5. CI/CD Scripts
- `pre_commit.py`: Pre-commit validation hooks
- `ci_validation.py`: CI/CD pipeline validation
- `release_notes.py`: Generate release notes from changes

## Usage Examples

### Generate OpenAPI from Model
```bash
python scripts/generate_openapi.py \
  --model models/user_management_user_v1.model.json \
  --output schemas/user_management_api_v1.openapi.yaml
```

### Validate Taxonomy Compliance
```bash
python scripts/validate_taxonomy.py \
  --taxonomy taxonomy/business_taxonomy_v1.json \
  --models models/ \
  --schemas schemas/
```

### Generate Documentation
```bash
python scripts/generate_docs.py \
  --openapi schemas/user_management_api_v1.openapi.yaml \
  --output docs/api-reference.md
```

### Check for Breaking Changes
```bash
python scripts/check_breaking_changes.py \
  --old schemas/user_management_api_v1.openapi.yaml \
  --new schemas/user_management_api_v2.openapi.yaml
```

## Development Setup

### Prerequisites
```bash
pip install -r requirements.txt
```

### Requirements
- Python 3.8+
- OpenAPI Generator CLI
- JSON Schema Validator
- GraphQL Core
- Azure CLI (for Purview integration)

### Configuration
```bash
# Copy configuration template
cp config.example.yaml config.yaml

# Edit configuration
vim config.yaml
```

## Integration with Azure Tools

### Purview Integration
```python
from azure.purview.catalog import PurviewClient

client = PurviewClient(
    endpoint="https://your-purview.purview.azure.com",
    credential=DefaultAzureCredential()
)

# Register data models in Purview
client.entities.create_entity(...)
```

### Synapse Integration
```python
from azure.synapse import SynapseClient

client = SynapseClient(
    endpoint="https://your-synapse.dev.azuresynapse.net",
    credential=DefaultAzureCredential()
)

# Create datasets from models
client.datasets.create_or_update_dataset(...)
```

## Automation Workflow

### Git Hooks Setup
```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Run validation on all files
pre-commit run --all-files
```

### CI/CD Pipeline
```yaml
# .github/workflows/validate-api.yml
name: Validate API Changes
on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Validate API
        run: |
          python scripts/validate_openapi.py schemas/
          python scripts/validate_taxonomy.py taxonomy/
          python scripts/check_breaking_changes.py
```

## Monitoring & Reporting

### Metrics Collection
- Schema validation success rate
- Taxonomy compliance percentage
- API documentation coverage
- Breaking change detection accuracy

### Automated Reporting
```bash
# Generate weekly compliance report
python scripts/generate_report.py \
  --type weekly \
  --output reports/weekly_compliance_$(date +%Y%m%d).md
```

## Best Practices

### Script Development
1. Include comprehensive error handling
2. Add logging for debugging
3. Write unit tests for all scripts
4. Document all command-line options
5. Follow consistent naming conventions

### Security Considerations
1. Never hardcode credentials
2. Use Azure managed identities
3. Implement least privilege access
4. Log sensitive operations securely
5. Validate all inputs thoroughly
