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

  # Concat: Add devices to existing config
  ./config_mapper.py -c conf.yaml -i ping_template.yaml lmr_ping_devices.yaml
  ./config_mapper.py -c conf.yaml -i tmpl1.yaml vals1.yaml -i tmpl2.yaml vals2.yaml

  # Combine: Create new config from multiple template/values pairs
  ./config_mapper.py -m output.yaml -i ping_template.yaml lmr.yaml -i other_tmpl.yaml washington.yaml

Note: Each -i/--input takes TEMPLATE then VALUES as separate args (tab-completion friendly).
''')

    parser.add_argument('positional', nargs='*', metavar='ARG',
                        help='Default mode: TEMPLATE_FILE MAP_FILE [OUTPUT_FILE]')
    parser.add_argument('-c', '--concat', metavar='CONFIG',
                        help='Concatenate: append rendered instances onto CONFIG file')
    parser.add_argument('-m', '--combine-multiple', metavar='OUTPUT',
                        dest='combine_multiple',
                        help='Combine: create new config at OUTPUT from multiple inputs')
    parser.add_argument('-i', '--input', nargs=2, metavar=('TEMPLATE', 'VALUES'),
                        action='append', dest='inputs',
                        help='Template and values file pair (can be repeated)')

    return parser


def load_yaml_file(filepath):
    """Load and parse a YAML file."""
    with open(filepath, 'r') as f:
        return yaml.safe_load(f)


def render_template(template_file, config_data):
    """Render a Jinja2 template with the given config data."""
    env = Environment(loader=FileSystemLoader('.'))
    template = env.get_template(template_file)
    # Handle YAML files that are plain lists (no root key)
    if isinstance(config_data, list):
        config_data = {'ping_devices': config_data}
    return template.render(**config_data)


def extract_instances_section(rendered):
    """Extract instance entries from rendered content (skip init_config: and instances: headers).

    If the template has no headers, return the content as-is (stripped).
    """
    lines = rendered.split('\n')

    # Check if this template has the standard headers
    has_instances_header = any(line.strip() == 'instances:' for line in lines)

    if has_instances_header:
        # Extract only the content after 'instances:'
        instance_lines = []
        in_instances = False
        for line in lines:
            if line.strip() == 'instances:':
                in_instances = True
                continue
            if in_instances and line.strip():
                instance_lines.append(line)
        return '\n'.join(instance_lines)
    else:
        # No headers - return content as-is, stripping empty lines at start/end
        return rendered.strip()


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
    """Concat mode: append rendered instances onto existing CONFIG file."""
    if not args.inputs:
        print("Error: --concat requires at least one -i/--input TEMPLATE VALUES pair")
        print("Usage: ./config_mapper.py -c CONFIG -i TEMPLATE VALUES [-i TEMPLATE VALUES ...]")
        sys.exit(1)

    config_file = args.concat

    # Process each input pair
    with open(config_file, 'a') as f:
        for template_file, values_file in args.inputs:
            config_data = load_yaml_file(values_file)
            rendered = render_template(template_file, config_data)
            instances_only = extract_instances_section(rendered)
            f.write('\n' + instances_only)
            print(f"Appended instances from '{values_file}' (template: {template_file})")

    print(f"Done. Appended {len(args.inputs)} file(s) to '{config_file}'")


def mode_combine_multiple(args):
    """Combine mode: create new config from multiple template/values pairs."""
    if not args.inputs or len(args.inputs) < 2:
        print("Error: --combine-multiple requires at least 2 -i/--input TEMPLATE VALUES pairs")
        print("Usage: ./config_mapper.py -m OUTPUT -i TEMPLATE VALUES -i TEMPLATE VALUES [...]")
        sys.exit(1)

    output_file = args.combine_multiple

    # Process first pair - include full output with headers
    first_template, first_values = args.inputs[0]
    config_data = load_yaml_file(first_values)
    rendered_config = render_template(first_template, config_data)

    with open(output_file, 'w') as f:
        f.write(rendered_config)
        print(f"Created base from '{first_values}' (template: {first_template})")

        # Process remaining pairs - extract instances only
        for template_file, values_file in args.inputs[1:]:
            config_data = load_yaml_file(values_file)
            rendered = render_template(template_file, config_data)
            instances_only = extract_instances_section(rendered)
            f.write('\n' + instances_only)
            print(f"Added instances from '{values_file}' (template: {template_file})")

    print(f"Done. Combined {len(args.inputs)} file(s) into '{output_file}'")


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
