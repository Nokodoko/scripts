#!/usr/bin/env python3
import argparse
import yaml
import sys
from jinja2 import Environment, FileSystemLoader


def create_argument_parser():
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        description='Generate Xymon monitoring configs from YAML + Jinja2 templates.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''Examples:
  # Default mode
  ./config_mapper.py ping_template.yaml lmr_ping_devices.yaml conf.yaml

  # Concat: Add devices to existing config (one or more TEMPLATE:VALUES pairs)
  ./config_mapper.py -c conf.yaml ping_template.yaml:lmr_ping_devices.yaml
  ./config_mapper.py -c conf.yaml tmpl1.yaml:vals1.yaml tmpl2.yaml:vals2.yaml

  # Combine: Create new config from multiple TEMPLATE:VALUES pairs
  ./config_mapper.py -m conf.yaml ping_template.yaml:lmr_ping_devices.yaml other_template.yaml:washington_ping_devices.yaml

Note: TEMPLATE:VALUES pairs allow each values file to use its own template.
''')

    parser.add_argument('positional', nargs='*', metavar='ARG',
                        help='Default mode: TEMPLATE_FILE MAP_FILE [OUTPUT_FILE]')
    parser.add_argument('-c', '--concat', nargs='+', metavar='ARGS',
                        help='Concatenate: CONFIG_FILE followed by TEMPLATE:VALUES pairs')
    parser.add_argument('-m', '--combine-multiple', nargs='+', metavar='ARGS',
                        dest='combine_multiple',
                        help='Combine: OUTPUT_FILE followed by 2+ TEMPLATE:VALUES pairs')

    return parser


def parse_template_values_pair(pair_str):
    """Parse a TEMPLATE:VALUES pair string into (template, values) tuple."""
    if ':' not in pair_str:
        return None, None
    parts = pair_str.split(':', 1)
    if len(parts) != 2:
        return None, None
    return parts[0], parts[1]


def load_yaml_file(filepath):
    """Load and parse a YAML file."""
    with open(filepath, 'r') as f:
        return yaml.safe_load(f)


def render_template(template_file, config_data):
    """Render a Jinja2 template with the given config data."""
    env = Environment(loader=FileSystemLoader('.'))
    template = env.get_template(template_file)
    return template.render(**config_data)


def extract_instances_section(rendered):
    """Extract instance entries from rendered content (skip init_config: and instances: headers)."""
    lines = rendered.split('\n')
    # Find where instances start (after 'instances:' line)
    instance_lines = []
    in_instances = False
    for line in lines:
        if line.strip() == 'instances:':
            in_instances = True
            continue
        if in_instances and line.strip():
            instance_lines.append(line)
    return '\n'.join(instance_lines)


def mode_default(args):
    """Default mode: TEMPLATE_FILE MAP_FILE [OUTPUT_FILE]"""
    if len(args.positional) < 2:
        print("Error: Default mode requires at least TEMPLATE_FILE and MAP_FILE")
        print("Usage: ./config_mapper.py TEMPLATE_FILE MAP_FILE [OUTPUT_FILE]")
        sys.exit(1)

    template_file = args.positional[0]
    map_file = args.positional[1]
    output_file = args.positional[2] if len(args.positional) >= 3 else 'conf.yaml'

    if len(args.positional) < 3:
        print(f"No output file name was given, will default to '{output_file}'")

    config_data = load_yaml_file(map_file)
    rendered_config = render_template(template_file, config_data)

    with open(output_file, 'w') as f:
        f.write(rendered_config)
    print("New configuration file generated!")


def mode_concat(args):
    """Concat mode: append rendered TEMPLATE:VALUES pairs onto existing CONFIG file."""
    if len(args.concat) < 2:
        print("Error: --concat requires CONFIG_FILE followed by at least one TEMPLATE:VALUES pair")
        print("Usage: ./config_mapper.py -c CONFIG_FILE TEMPLATE:VALUES [TEMPLATE:VALUES ...]")
        sys.exit(1)

    config_file = args.concat[0]
    pairs = args.concat[1:]

    # Validate all pairs before processing
    parsed_pairs = []
    for pair_str in pairs:
        template_file, values_file = parse_template_values_pair(pair_str)
        if template_file is None:
            print(f"Error: Invalid TEMPLATE:VALUES pair: '{pair_str}'")
            print("Expected format: TEMPLATE_FILE:VALUES_FILE (e.g., ping_template.yaml:devices.yaml)")
            sys.exit(1)
        parsed_pairs.append((template_file, values_file))

    # Process each pair
    with open(config_file, 'a') as f:
        for template_file, values_file in parsed_pairs:
            config_data = load_yaml_file(values_file)
            rendered = render_template(template_file, config_data)
            instances_only = extract_instances_section(rendered)
            f.write('\n' + instances_only)
            print(f"Appended instances from '{values_file}' (template: {template_file})")

    print(f"Done. Appended {len(parsed_pairs)} file(s) to '{config_file}'")


def mode_combine_multiple(args):
    """Combine mode: create new config from multiple TEMPLATE:VALUES pairs."""
    if len(args.combine_multiple) < 3:
        print("Error: --combine-multiple requires OUTPUT_FILE followed by at least 2 TEMPLATE:VALUES pairs")
        print("Usage: ./config_mapper.py -m OUTPUT_FILE TEMPLATE:VALUES TEMPLATE:VALUES [...]")
        sys.exit(1)

    output_file = args.combine_multiple[0]
    pairs = args.combine_multiple[1:]

    # Validate all pairs before processing
    parsed_pairs = []
    for pair_str in pairs:
        template_file, values_file = parse_template_values_pair(pair_str)
        if template_file is None:
            print(f"Error: Invalid TEMPLATE:VALUES pair: '{pair_str}'")
            print("Expected format: TEMPLATE_FILE:VALUES_FILE (e.g., ping_template.yaml:devices.yaml)")
            sys.exit(1)
        parsed_pairs.append((template_file, values_file))

    # Process first pair - include full output with headers
    first_template, first_values = parsed_pairs[0]
    config_data = load_yaml_file(first_values)
    rendered_config = render_template(first_template, config_data)

    with open(output_file, 'w') as f:
        f.write(rendered_config)
        print(f"Created base from '{first_values}' (template: {first_template})")

        # Process remaining pairs - extract instances only
        for template_file, values_file in parsed_pairs[1:]:
            config_data = load_yaml_file(values_file)
            rendered = render_template(template_file, config_data)
            instances_only = extract_instances_section(rendered)
            f.write('\n' + instances_only)
            print(f"Added instances from '{values_file}' (template: {template_file})")

    print(f"Done. Combined {len(parsed_pairs)} file(s) into '{output_file}'")


def main():
    parser = create_argument_parser()
    args = parser.parse_args()

    # Determine which mode to run
    if args.concat:
        mode_concat(args)
    elif args.combine_multiple:
        mode_combine_multiple(args)
    elif args.positional:
        mode_default(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
