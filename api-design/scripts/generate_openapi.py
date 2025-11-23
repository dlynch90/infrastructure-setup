#!/usr/bin/env python3
"""
OpenAPI Specification Generator

Generates OpenAPI 3.0 specifications from data models and taxonomy definitions.

Usage:
    python generate_openapi.py --model models/user.model.json --output schemas/user_api.yaml
"""

import argparse
import json
import yaml
from pathlib import Path
from typing import Dict, Any, List
from datetime import datetime


class OpenAPIGenerator:
    """Generate OpenAPI specifications from data models."""

    def __init__(self, taxonomy_file: str = None):
        self.taxonomy = {}
        if taxonomy_file and Path(taxonomy_file).exists():
            with open(taxonomy_file, 'r') as f:
                self.taxonomy = json.load(f)

    def generate_from_model(self, model_file: str) -> Dict[str, Any]:
        """Generate OpenAPI spec from a data model file."""

        # Load the data model
        with open(model_file, 'r') as f:
            model = json.load(f)

        # Extract model metadata
        model_info = model.get('model', {})
        entities = model.get('entities', [])

        # Generate OpenAPI structure
        openapi_spec = {
            'openapi': '3.0.3',
            'info': {
                'title': f"{model_info.get('domain', 'API').replace('_', ' ').title()} API",
                'version': model_info.get('version', '1.0.0'),
                'description': model_info.get('description', ''),
                'contact': {
                    'name': 'API Development Team',
                    'email': 'api@empathyfirstmedia.com'
                }
            },
            'servers': [
                {
                    'url': 'https://api.empathyfirstmedia.com/v1',
                    'description': 'Production server'
                }
            ],
            'paths': {},
            'components': {
                'schemas': {},
                'responses': self._generate_standard_responses()
            }
        }

        # Generate schemas and paths for each entity
        for entity in entities:
            entity_name = entity['name']
            schema_name = entity_name.lower()

            # Generate schema
            openapi_spec['components']['schemas'][entity_name] = self._generate_entity_schema(entity)

            # Generate CRUD paths
            entity_paths = self._generate_entity_paths(entity_name, schema_name)
            openapi_spec['paths'].update(entity_paths)

        # Add taxonomy metadata
        if self.taxonomy:
            openapi_spec['x-taxonomy'] = {
                'domain': model_info.get('domain'),
                'version': model_info.get('version'),
                'compliance': self._extract_compliance_requirements(entities)
            }

        return openapi_spec

    def _generate_entity_schema(self, entity: Dict[str, Any]) -> Dict[str, Any]:
        """Generate OpenAPI schema for an entity."""
        schema = {
            'type': 'object',
            'properties': {},
            'required': []
        }

        for attr in entity.get('attributes', []):
            attr_name = attr['name']
            attr_type = attr['type']

            # Map data types to OpenAPI types
            openapi_type = self._map_data_type(attr_type)
            schema['properties'][attr_name] = {
                'type': openapi_type['type'],
                'description': attr.get('description', ''),
                'example': self._generate_example_value(attr_type)
            }

            # Add format if specified
            if 'format' in openapi_type:
                schema['properties'][attr_name]['format'] = openapi_type['format']

            # Add constraints
            if attr.get('max_length'):
                schema['properties'][attr_name]['maxLength'] = attr['max_length']

            if attr.get('required', False):
                schema['required'].append(attr_name)

        # Add taxonomy metadata
        if 'taxonomy_classification' in entity:
            schema['x-taxonomy'] = entity['taxonomy_classification']

        return schema

    def _generate_entity_paths(self, entity_name: str, schema_name: str) -> Dict[str, Any]:
        """Generate CRUD paths for an entity."""
        base_path = f"/{schema_name}s"
        entity_path = f"{base_path}/{{{schema_name}Id}}"

        paths = {
            base_path: {
                'get': {
                    'summary': f'List {entity_name}s',
                    'operationId': f'list{entity_name}s',
                    'responses': {
                        '200': {
                            'description': 'Successful response',
                            'content': {
                                'application/json': {
                                    'schema': {
                                        'type': 'object',
                                        'properties': {
                                            'data': {
                                                'type': 'array',
                                                'items': {'$ref': f'#/components/schemas/{entity_name}'}
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
                'post': {
                    'summary': f'Create {entity_name}',
                    'operationId': f'create{entity_name}',
                    'requestBody': {
                        'required': True,
                        'content': {
                            'application/json': {
                                'schema': {'$ref': f'#/components/schemas/Create{entity_name}Request'}
                            }
                        }
                    },
                    'responses': {
                        '201': {
                            'description': f'{entity_name} created successfully',
                            'content': {
                                'application/json': {
                                    'schema': {'$ref': f'#/components/schemas/{entity_name}Response'}
                                }
                            }
                        }
                    }
                }
            },
            entity_path: {
                'get': {
                    'summary': f'Get {entity_name}',
                    'operationId': f'get{entity_name}',
                    'parameters': [
                        {
                            'name': f'{schema_name}Id',
                            'in': 'path',
                            'required': True,
                            'schema': {'type': 'string', 'format': 'uuid'}
                        }
                    ],
                    'responses': {
                        '200': {
                            'description': 'Successful response',
                            'content': {
                                'application/json': {
                                    'schema': {'$ref': f'#/components/schemas/{entity_name}Response'}
                                }
                            }
                        }
                    }
                }
            }
        }

        return paths

    def _generate_standard_responses(self) -> Dict[str, Any]:
        """Generate standard error responses."""
        return {
            'BadRequest': {
                'description': 'Bad request',
                'content': {
                    'application/json': {
                        'schema': {'$ref': '#/components/schemas/Error'}
                    }
                }
            },
            'Unauthorized': {
                'description': 'Authentication required',
                'content': {
                    'application/json': {
                        'schema': {'$ref': '#/components/schemas/Error'}
                    }
                }
            },
            'Forbidden': {
                'description': 'Access denied',
                'content': {
                    'application/json': {
                        'schema': {'$ref': '#/components/schemas/Error'}
                    }
                }
            },
            'NotFound': {
                'description': 'Resource not found',
                'content': {
                    'application/json': {
                        'schema': {'$ref': '#/components/schemas/Error'}
                    }
                }
            }
        }

    def _map_data_type(self, data_type: str) -> Dict[str, str]:
        """Map custom data types to OpenAPI types."""
        type_mapping = {
            'uuid': {'type': 'string', 'format': 'uuid'},
            'email': {'type': 'string', 'format': 'email'},
            'phone': {'type': 'string', 'format': 'phone'},
            'currency': {'type': 'number', 'format': 'decimal'},
            'datetime': {'type': 'string', 'format': 'date-time'},
            'date': {'type': 'string', 'format': 'date'},
            'enum': {'type': 'string'},
            'boolean': {'type': 'boolean'},
            'integer': {'type': 'integer'},
            'float': {'type': 'number', 'format': 'float'},
            'string': {'type': 'string'}
        }

        return type_mapping.get(data_type, {'type': 'string'})

    def _generate_example_value(self, data_type: str) -> Any:
        """Generate example values for different data types."""
        examples = {
            'uuid': '123e4567-e89b-12d3-a456-426614174000',
            'email': 'user@example.com',
            'phone': '+1-555-123-4567',
            'currency': 99.99,
            'datetime': '2023-11-23T10:30:00Z',
            'date': '2023-11-23',
            'boolean': True,
            'integer': 42,
            'float': 3.14,
            'string': 'example value'
        }

        return examples.get(data_type, 'example')

    def _extract_compliance_requirements(self, entities: List[Dict[str, Any]]) -> List[str]:
        """Extract compliance requirements from entities."""
        compliance = set()
        for entity in entities:
            if 'taxonomy_classification' in entity:
                compliance.update(entity['taxonomy_classification'].get('compliance', []))

        return list(compliance)


def main():
    parser = argparse.ArgumentParser(description='Generate OpenAPI specifications from data models')
    parser.add_argument('--model', required=True, help='Path to data model JSON file')
    parser.add_argument('--taxonomy', help='Path to taxonomy JSON file')
    parser.add_argument('--output', required=True, help='Output OpenAPI YAML file')

    args = parser.parse_args()

    # Generate OpenAPI specification
    generator = OpenAPIGenerator(args.taxonomy)
    spec = generator.generate_from_model(args.model)

    # Write to file
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'w') as f:
        yaml.dump(spec, f, default_flow_style=False, sort_keys=False)

    print(f"✅ OpenAPI specification generated: {args.output}")


if __name__ == '__main__':
    main()
