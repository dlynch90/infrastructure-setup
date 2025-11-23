# API Schemas Directory

## Purpose
This directory contains OpenAPI/Swagger specifications, JSON schemas, and GraphQL schemas for all APIs.

## File Naming Convention
```
{api_name}_{version}.openapi.yaml
Example: user_management_api_v1.openapi.yaml
```

## Schema Types

### 1. OpenAPI Specifications
- REST API endpoint definitions
- Request/response schemas
- Authentication requirements
- API versioning information

### 2. JSON Schemas
- Data validation schemas
- Entity structure definitions
- Business rule constraints

### 3. GraphQL Schemas
- Type definitions
- Query/Mutation schemas
- Subscription definitions

## Schema Generation

### Automated Generation from Models
```bash
# Generate OpenAPI from data models
python scripts/generate_openapi.py --model models/user_management_user_v1.model.json

# Generate JSON schemas from taxonomy
python scripts/generate_json_schema.py --taxonomy taxonomy/business_taxonomy_v1.json
```

### Manual Schema Creation
1. Start with data model as foundation
2. Apply taxonomy classifications
3. Add API-specific constraints
4. Include validation rules
5. Generate documentation

## Validation Pipeline

### Pre-commit Hooks
```bash
# Validate OpenAPI specifications
swagger-tools validate schemas/user_management_api_v1.openapi.yaml

# Validate JSON schemas
ajv validate -s schemas/user_schema_v1.json -d test_data.json

# Check taxonomy compliance
python scripts/validate_taxonomy.py schemas/
```

### CI/CD Integration
- Automated schema validation on PR
- Breaking change detection
- Documentation generation
- SDK generation from schemas

## Schema Evolution

### Versioning Strategy
- **MAJOR**: Breaking changes (incompatible API changes)
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (no API changes)

### Deprecation Process
1. Mark schema as deprecated with sunset date
2. Provide migration guide
3. Maintain backward compatibility
4. Remove after grace period

## Quality Assurance

### Coverage Metrics
- Schema completeness: 100% of entities covered
- Validation accuracy: >99% pass rate
- Documentation coverage: 100% of endpoints
- Taxonomy compliance: 100% adherence

### Testing Strategy
- Unit tests for schema validation
- Integration tests for API compliance
- Performance tests for schema processing
- Security tests for data exposure
