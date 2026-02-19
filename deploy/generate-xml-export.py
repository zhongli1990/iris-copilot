"""
Generate a single IRIS XML export file from all AIAgent UDL .cls files.
Produces a file importable via Studio (Tools > Import Local) or $system.OBJ.Load().

Usage:
    python generate-xml-export.py

Output:
    deploy/AIAgent-export.xml
"""

import os
import re
import xml.etree.ElementTree as ET
from xml.dom import minidom
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
CLS_DIR = SCRIPT_DIR.parent / "cls"
OUTPUT_FILE = SCRIPT_DIR / "AIAgent-export.xml"

# Version counter — increment each time the script is run
VERSION_FILE = SCRIPT_DIR / ".export-version"

# Class import order (dependencies first)
CLASS_ORDER = [
    "AIAgent/Util/JSON.cls",
    "AIAgent/Util/Logger.cls",
    "AIAgent/Model/Conversation.cls",
    "AIAgent/Model/Message.cls",
    "AIAgent/Model/Generation.cls",
    "AIAgent/Model/GenerationClass.cls",
    "AIAgent/Model/Version.cls",
    "AIAgent/Model/AuditEntry.cls",
    "AIAgent/Engine/CodeManager.cls",
    "AIAgent/Engine/ProductionManager.cls",
    "AIAgent/Engine/VersionManager.cls",
    "AIAgent/Engine/TestRunner.cls",
    "AIAgent/Engine/BridgeClient.cls",
    "AIAgent/Engine/Orchestrator.cls",
    "AIAgent/Templates/BusinessService.cls",
    "AIAgent/Templates/BusinessProcess.cls",
    "AIAgent/Templates/BusinessOperation.cls",
    "AIAgent/Templates/DataTransformation.cls",
    "AIAgent/Templates/RoutingRule.cls",
    "AIAgent/Templates/MessageClass.cls",
    "AIAgent/Templates/Factory.cls",
    "AIAgent/API/Dispatcher.cls",
    "AIAgent/UI/Chat.cls",
    "AIAgent/Install/Installer.cls",
]


def parse_udl_class(source: str) -> dict:
    """Parse a UDL .cls file into structured components."""
    result = {
        "name": "",
        "super": "",
        "description": [],
        "class_keywords": {},  # e.g. Abstract, DependsOn
        "parameters": [],
        "properties": [],
        "methods": [],
        "xdata": [],
        "storage": [],
        "projections": [],
        "indices": [],
    }

    lines = source.split("\n")
    i = 0

    # Collect leading /// description lines
    while i < len(lines):
        line = lines[i]
        if line.startswith("///"):
            result["description"].append(line[3:].strip() if len(line) > 3 else "")
            i += 1
        elif line.strip() == "":
            i += 1
        else:
            break

    # Parse Class declaration
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("Class "):
            # Parse: Class Name Extends Super [ keywords ]
            class_match = re.match(
                r'Class\s+([\w.]+)\s+Extends\s+([\w.%,\s()]+?)(?:\s*\[(.+?)\])?\s*$',
                line
            )
            if class_match:
                result["name"] = class_match.group(1)
                result["super"] = class_match.group(2).strip()
                if class_match.group(3):
                    result["class_keywords"] = parse_bracket_keywords(class_match.group(3))
            else:
                # Try without Extends
                class_match2 = re.match(r'Class\s+([\w.]+)(?:\s+Extends\s+([\w.%,\s()]+?))?(?:\s*\[(.+?)\])?\s*$', line)
                if class_match2:
                    result["name"] = class_match2.group(1)
                    result["super"] = (class_match2.group(2) or "").strip()
                    if class_match2.group(3):
                        result["class_keywords"] = parse_bracket_keywords(class_match2.group(3))
            i += 1
            break
        i += 1

    # Skip opening brace
    while i < len(lines) and lines[i].strip() in ("{", ""):
        i += 1

    # Parse class body
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Skip empty lines
        if stripped == "":
            i += 1
            continue

        # End of class
        if stripped == "}":
            break

        # Collect description comments before a member
        member_desc = []
        while stripped.startswith("///"):
            member_desc.append(stripped[3:].strip() if len(stripped) > 3 else "")
            i += 1
            if i >= len(lines):
                break
            line = lines[i]
            stripped = line.strip()

        # Skip blank lines after comments
        while i < len(lines) and lines[i].strip() == "":
            i += 1
            if i >= len(lines):
                break
            line = lines[i]
            stripped = line.strip()

        # Parameter
        if stripped.startswith("Parameter "):
            param = parse_parameter(stripped, member_desc)
            if param:
                result["parameters"].append(param)
            i += 1
            continue

        # Property
        if stripped.startswith("Property "):
            prop = parse_property(stripped, member_desc)
            if prop:
                result["properties"].append(prop)
            i += 1
            continue

        # Index
        if stripped.startswith("Index "):
            idx = parse_index(stripped, member_desc)
            if idx:
                result["indices"].append(idx)
            i += 1
            continue

        # ClassMethod or Method
        if stripped.startswith("ClassMethod ") or stripped.startswith("Method "):
            method, i = parse_method(lines, i, member_desc)
            if method:
                result["methods"].append(method)
            continue

        # XData
        if stripped.startswith("XData "):
            xdata, i = parse_xdata(lines, i, member_desc)
            if xdata:
                result["xdata"].append(xdata)
            continue

        # Storage
        if stripped.startswith("Storage "):
            storage, i = parse_storage(lines, i)
            if storage:
                result["storage"].append(storage)
            continue

        # Skip anything else (comments, blank lines)
        i += 1

    return result


def udl_formalspec_to_xml(udl_spec: str) -> str:
    """Convert UDL formal spec to IRIS XML FormalSpec format.

    UDL:  param As %String, param2 As %Integer = 0, Output pOut As %String
    XML:  param:%String,param2:%Integer=0,*pOut:%String

    UDL uses 'As' keyword; XML uses ':' separator.
    Output params get '*' prefix, ByRef params get '&' prefix.
    """
    if not udl_spec.strip():
        return ""

    # Split on commas, but respect nested parens/quotes
    params = split_params(udl_spec)
    xml_params = []

    for param in params:
        param = param.strip()
        if not param:
            continue

        prefix = ""
        # Check for Output/ByRef modifiers
        if param.startswith("Output "):
            prefix = "*"
            param = param[7:].strip()
        elif param.startswith("ByRef "):
            prefix = "&"
            param = param[6:].strip()

        # Parse: name As Type = default
        m = re.match(r'(\w+)\s+As\s+([\w.%]+(?:\([^)]*\))?)\s*(?:=\s*(.+))?$', param)
        if m:
            name = m.group(1)
            ptype = m.group(2)
            default = m.group(3)
            # Strip type parameters like (MAXLEN=256) for FormalSpec
            ptype_base = re.sub(r'\([^)]*\)', '', ptype)
            result = f"{prefix}{name}:{ptype_base}"
            if default is not None:
                result += f"={default.strip()}"
            xml_params.append(result)
        else:
            # No type specified, or already in colon format
            xml_params.append(f"{prefix}{param}")

    return ",".join(xml_params)


def split_params(spec: str) -> list:
    """Split formal spec by commas, respecting nested parens and quotes."""
    params = []
    depth = 0
    in_quote = False
    current = ""
    for ch in spec:
        if ch == '"' and not in_quote:
            in_quote = True
            current += ch
        elif ch == '"' and in_quote:
            in_quote = False
            current += ch
        elif ch == '(' and not in_quote:
            depth += 1
            current += ch
        elif ch == ')' and not in_quote:
            depth -= 1
            current += ch
        elif ch == ',' and depth == 0 and not in_quote:
            params.append(current)
            current = ""
        else:
            current += ch
    if current.strip():
        params.append(current)
    return params


def parse_bracket_keywords(text: str) -> dict:
    """Parse [ Key = Value, Key2 = Value2 ] content.

    Respects nested braces {} and parentheses () so that expressions like
    InitialExpression = {$zdatetime($ztimestamp, 3, 1)} are not split at
    the commas inside the braces.
    """
    result = {}
    # Split by commas, respecting nested {} and ()
    parts = []
    depth = 0
    in_quote = False
    current = ""
    for ch in text:
        if ch == '"' and not in_quote:
            in_quote = True
            current += ch
        elif ch == '"' and in_quote:
            in_quote = False
            current += ch
        elif not in_quote and ch in ('(', '{'):
            depth += 1
            current += ch
        elif not in_quote and ch in (')', '}'):
            depth -= 1
            current += ch
        elif ch == ',' and depth == 0 and not in_quote:
            parts.append(current)
            current = ""
        else:
            current += ch
    if current.strip():
        parts.append(current)

    for part in parts:
        if '=' in part:
            k, v = part.split('=', 1)
            result[k.strip()] = v.strip().strip('"')
        else:
            result[part.strip()] = "1"
    return result


def parse_parameter(line: str, desc: list) -> dict:
    """Parse: Parameter NAME = "value"; or Parameter NAME As Type;"""
    m = re.match(r'Parameter\s+(\w+)\s*=\s*"?(.*?)"?\s*;', line)
    if m:
        return {"name": m.group(1), "default": m.group(2), "description": desc}
    m = re.match(r'Parameter\s+(\w+)\s*;', line)
    if m:
        return {"name": m.group(1), "default": "", "description": desc}
    m = re.match(r'Parameter\s+(\w+)\s+As\s+(\S+)\s*=\s*"?(.*?)"?\s*;', line)
    if m:
        return {"name": m.group(1), "type": m.group(2), "default": m.group(3), "description": desc}
    return None


def parse_property(line: str, desc: list) -> dict:
    """Parse: Property Name As Type(PARAMS) [ keywords ];"""
    # Match property with type, optional parameters, and optional keywords
    m = re.match(
        r'Property\s+(\w+)\s+As\s+([^\[;]+?)(?:\s*\[(.+?)\])?\s*;',
        line
    )
    if m:
        prop = {
            "name": m.group(1),
            "type_full": m.group(2).strip(),
            "keywords": {},
            "description": desc,
        }
        # Parse type and type parameters
        type_m = re.match(r'([\w.%]+)(?:\((.+)\))?', prop["type_full"])
        if type_m:
            prop["type"] = type_m.group(1)
            prop["type_params"] = type_m.group(2) or ""
        else:
            prop["type"] = prop["type_full"]
            prop["type_params"] = ""

        if m.group(3):
            prop["keywords"] = parse_bracket_keywords(m.group(3))
        return prop
    return None


def parse_index(line: str, desc: list) -> dict:
    """Parse: Index IndexName On (Props) [ keywords ];"""
    m = re.match(r'Index\s+(\w+)\s+On\s+(.+?)(?:\s*\[(.+?)\])?\s*;', line)
    if m:
        return {
            "name": m.group(1),
            "properties": m.group(2).strip(),
            "keywords": parse_bracket_keywords(m.group(3)) if m.group(3) else {},
            "description": desc,
        }
    return None


def parse_method(lines: list, start: int, desc: list) -> tuple:
    """Parse a Method or ClassMethod block including its body."""
    line = lines[start].strip()

    # Determine if ClassMethod
    is_class_method = line.startswith("ClassMethod ")
    keyword = "ClassMethod" if is_class_method else "Method"

    # Parse declaration
    # Handle multi-line declarations
    decl = line
    i = start
    while not decl.rstrip().endswith("{") and i < len(lines) - 1:
        i += 1
        decl += " " + lines[i].strip()

    # Remove trailing {
    decl = decl.rstrip().rstrip("{").strip()

    # Parse: (Class)Method Name(args) As ReturnType [ keywords ]
    m = re.match(
        rf'{keyword}\s+(\w+)\((.*?)\)(?:\s+As\s+([\w.%]+))?(?:\s*\[(.+?)\])?\s*$',
        decl,
        re.DOTALL
    )

    method = {
        "name": "",
        "is_class_method": is_class_method,
        "formal_spec": "",
        "return_type": "",
        "keywords": {},
        "description": desc,
        "implementation": [],
    }

    if m:
        method["name"] = m.group(1)
        method["formal_spec"] = m.group(2).strip() if m.group(2) else ""
        method["return_type"] = m.group(3) or ""
        if m.group(4):
            method["keywords"] = parse_bracket_keywords(m.group(4))
    else:
        # Fallback: extract method name at minimum
        m2 = re.match(rf'{keyword}\s+(\w+)', decl)
        if m2:
            method["name"] = m2.group(1)
            # Get everything between parens
            paren_m = re.search(r'\(([^)]*)\)', decl)
            if paren_m:
                method["formal_spec"] = paren_m.group(1).strip()
            ret_m = re.search(r'As\s+([\w.%]+)', decl)
            if ret_m:
                method["return_type"] = ret_m.group(1)
            kw_m = re.search(r'\[(.+?)\]\s*$', decl)
            if kw_m:
                method["keywords"] = parse_bracket_keywords(kw_m.group(1))

    # Find opening brace
    i = start
    while i < len(lines) and "{" not in lines[i]:
        i += 1
    i += 1  # skip the line with {

    # Collect method body until matching }
    brace_depth = 1
    body_lines = []
    while i < len(lines) and brace_depth > 0:
        body_line = lines[i]
        brace_depth += body_line.count("{") - body_line.count("}")
        if brace_depth > 0:
            body_lines.append(body_line)
        elif brace_depth == 0:
            # Last line — check if there's content before the closing }
            last = body_line.rstrip()
            if last != "}":
                # Content on same line as closing brace
                idx = last.rfind("}")
                if idx > 0:
                    body_lines.append(last[:idx])
        i += 1

    method["implementation"] = body_lines

    if not method["name"]:
        return None, i
    return method, i


def parse_xdata(lines: list, start: int, desc: list) -> tuple:
    """Parse an XData block."""
    line = lines[start].strip()

    # Parse: XData Name [ XMLNamespace = "..." ]
    m = re.match(r'XData\s+(\w+)(?:\s*\[(.+?)\])?\s*$', line)
    xdata = {
        "name": m.group(1) if m else "Unknown",
        "keywords": parse_bracket_keywords(m.group(2)) if m and m.group(2) else {},
        "description": desc,
        "data": [],
    }

    # Find opening brace
    i = start
    while i < len(lines) and "{" not in lines[i]:
        i += 1
    i += 1  # skip opening brace line

    # Collect until matching closing brace of the XData block.
    # Count all braces so XData can safely contain JavaScript/JSON blocks.
    brace_depth = 1
    while i < len(lines) and brace_depth > 0:
        body_line = lines[i]
        brace_depth += body_line.count("{") - body_line.count("}")
        if brace_depth > 0:
            xdata["data"].append(body_line)
        elif brace_depth == 0:
            # Content before the terminating brace on the same line
            last = body_line.rstrip()
            if last != "}":
                idx = last.rfind("}")
                if idx > 0:
                    xdata["data"].append(last[:idx])
        i += 1

    return xdata, i


def parse_storage(lines: list, start: int) -> tuple:
    """Parse a Storage block (pass through as raw text)."""
    line = lines[start].strip()
    m = re.match(r'Storage\s+(\w+)\s*', line)
    name = m.group(1) if m else "Default"

    # Find opening brace
    i = start
    while i < len(lines) and "{" not in lines[i]:
        i += 1
    i += 1

    # Collect raw storage XML until closing }
    storage_lines = []
    brace_depth = 1
    while i < len(lines) and brace_depth > 0:
        sline = lines[i]
        stripped = sline.strip()
        if stripped == "}":
            brace_depth -= 1
            if brace_depth == 0:
                i += 1
                break
        storage_lines.append(sline)
        i += 1

    return {"name": name, "data": storage_lines}, i


def class_to_xml(cls_data: dict) -> str:
    """Convert parsed class data to IRIS XML export format."""
    parts = []

    # Open Class element
    parts.append(f'<Class name="{cls_data["name"]}">')

    # Description
    if cls_data["description"]:
        desc_text = "\n".join(cls_data["description"])
        parts.append(f"<Description>{escape_xml(desc_text)}</Description>")

    # Super
    if cls_data["super"]:
        parts.append(f'<Super>{escape_xml(cls_data["super"])}</Super>')

    # Class keywords
    for key, val in cls_data.get("class_keywords", {}).items():
        if key == "DependsOn":
            parts.append(f"<DependsOn>{escape_xml(val)}</DependsOn>")
        elif key == "Abstract":
            parts.append("<Abstract>1</Abstract>")
        elif key == "CompileAfter":
            parts.append(f"<CompileAfter>{escape_xml(val)}</CompileAfter>")

    # Parameters
    for param in cls_data["parameters"]:
        parts.append(f'<Parameter name="{param["name"]}">')
        if param.get("description"):
            parts.append(f"<Description>{escape_xml(chr(10).join(param['description']))}</Description>")
        if param.get("type"):
            parts.append(f"<Type>{param['type']}</Type>")
        if param.get("default", "") != "":
            parts.append(f"<Default>{escape_xml(param['default'])}</Default>")
        parts.append("</Parameter>")
        parts.append("")

    # Properties
    for prop in cls_data["properties"]:
        parts.append(f'<Property name="{prop["name"]}">')
        if prop.get("description"):
            parts.append(f"<Description>{escape_xml(chr(10).join(prop['description']))}</Description>")
        if prop.get("type"):
            parts.append(f"<Type>{prop['type']}</Type>")
        # Type parameters (MAXLEN, etc.)
        if prop.get("type_params"):
            for tp in re.findall(r'(\w+)\s*=\s*(\S+)', prop["type_params"]):
                parts.append(f'<Parameter name="{tp[0]}" value="{tp[1]}"/>')
        # Keywords (InitialExpression, etc.)
        for key, val in prop.get("keywords", {}).items():
            if key == "InitialExpression":
                # Strip UDL expression braces: {$zdatetime($h,3,1)} -> $zdatetime($h,3,1)
                # In UDL, {..} means "ObjectScript expression". XML stores the raw expression.
                expr = val
                if expr.startswith("{") and expr.endswith("}"):
                    expr = expr[1:-1]
                parts.append(f"<InitialExpression>{escape_xml(expr)}</InitialExpression>")
            elif key == "Required":
                parts.append("<Required>1</Required>")
            elif key == "Private":
                parts.append("<Private>1</Private>")
            elif key == "Calculated":
                parts.append("<Calculated>1</Calculated>")
        parts.append("</Property>")
        parts.append("")

    # Indices
    for idx in cls_data.get("indices", []):
        parts.append(f'<Index name="{idx["name"]}">')
        if idx.get("description"):
            parts.append(f"<Description>{escape_xml(chr(10).join(idx['description']))}</Description>")
        parts.append(f"<Properties>{escape_xml(idx['properties'])}</Properties>")
        for key, val in idx.get("keywords", {}).items():
            if key == "Unique":
                parts.append("<Unique>1</Unique>")
            elif key == "Type":
                parts.append(f"<Type>{escape_xml(val)}</Type>")
        parts.append("</Index>")
        parts.append("")

    # Methods
    for method in cls_data["methods"]:
        parts.append(f'<Method name="{method["name"]}">')
        if method.get("description"):
            parts.append(f"<Description>{escape_xml(chr(10).join(method['description']))}</Description>")
        if method["is_class_method"]:
            parts.append("<ClassMethod>1</ClassMethod>")
        if method.get("formal_spec"):
            xml_spec = udl_formalspec_to_xml(method["formal_spec"])
            parts.append(f"<FormalSpec>{escape_xml(xml_spec)}</FormalSpec>")
        if method.get("return_type"):
            parts.append(f"<ReturnType>{method['return_type']}</ReturnType>")
        for key, val in method.get("keywords", {}).items():
            if key == "Private":
                parts.append("<Private>1</Private>")
            elif key == "Abstract":
                parts.append("<Abstract>1</Abstract>")

        # Implementation
        impl_text = "\n".join(method["implementation"])
        parts.append(f"<Implementation><![CDATA[\n{impl_text}\n]]></Implementation>")
        parts.append("</Method>")
        parts.append("")

    # XData blocks
    for xdata in cls_data["xdata"]:
        parts.append(f'<XData name="{xdata["name"]}">')
        if xdata.get("description"):
            parts.append(f"<Description>{escape_xml(chr(10).join(xdata['description']))}</Description>")
        # XMLNamespace must be a child element, not an attribute
        if "XMLNamespace" in xdata.get("keywords", {}):
            parts.append(f'<XMLNamespace>{escape_xml(xdata["keywords"]["XMLNamespace"])}</XMLNamespace>')
        # MimeType if present
        if "MimeType" in xdata.get("keywords", {}):
            parts.append(f'<MimeType>{escape_xml(xdata["keywords"]["MimeType"])}</MimeType>')
        xdata_content = "\n".join(xdata["data"])
        parts.append(f"<Data><![CDATA[\n{xdata_content}\n]]></Data>")
        parts.append("</XData>")
        parts.append("")

    # Storage blocks
    for storage in cls_data.get("storage", []):
        parts.append(f'<Storage name="{storage["name"]}">')
        storage_content = "\n".join(storage["data"])
        # Storage usually contains XML elements directly
        parts.append(storage_content)
        parts.append("</Storage>")
        parts.append("")

    parts.append("</Class>")
    return "\n".join(parts)


def escape_xml(text: str) -> str:
    """Escape XML special characters (but not in CDATA sections)."""
    return (text
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;"))


def get_next_version() -> int:
    """Read and increment the version counter."""
    version = 1
    if VERSION_FILE.exists():
        try:
            version = int(VERSION_FILE.read_text().strip()) + 1
        except ValueError:
            version = 1
    VERSION_FILE.write_text(str(version))
    return version


def main():
    version = get_next_version()
    versioned_file = SCRIPT_DIR / f"AIAgent-export-v{version}.xml"

    print(f"IRIS Copilot — XML Export Generator")
    print(f"===================================")
    print(f"Version: {version}")
    print(f"Source:  {CLS_DIR}")
    print(f"Output:  {OUTPUT_FILE}")
    print(f"Copy:    {versioned_file}")
    print()

    # Build the XML export document
    xml_parts = []
    xml_parts.append('<?xml version="1.0" encoding="UTF-8"?>')
    xml_parts.append(f'<Export generator="IRIS" version="26" exportversion="{version}">')
    xml_parts.append("")

    class_count = 0
    errors = []

    for cls_path in CLASS_ORDER:
        full_path = CLS_DIR / cls_path.replace("/", os.sep)
        class_name = cls_path.replace("/", ".").replace(".cls", "")

        if not full_path.exists():
            print(f"  WARNING: {cls_path} not found, skipping")
            errors.append(cls_path)
            continue

        print(f"  Processing {class_name} ...", end=" ")

        try:
            source = full_path.read_text(encoding="utf-8")
            cls_data = parse_udl_class(source)

            if not cls_data["name"]:
                cls_data["name"] = class_name

            xml_content = class_to_xml(cls_data)
            xml_parts.append(xml_content)
            xml_parts.append("")
            class_count += 1
            print("OK")
        except Exception as e:
            print(f"ERROR: {e}")
            errors.append(f"{cls_path}: {e}")

    xml_parts.append("</Export>")

    # Write output — both latest and versioned copy
    output_text = "\n".join(xml_parts)
    OUTPUT_FILE.write_text(output_text, encoding="utf-8")
    versioned_file.write_text(output_text, encoding="utf-8")

    print()
    print(f"===================================")
    print(f"Generated: {OUTPUT_FILE}")
    print(f"Versioned: {versioned_file}")
    print(f"Version:   v{version}")
    print(f"Classes:   {class_count} / {len(CLASS_ORDER)}")
    if errors:
        print(f"Errors:    {len(errors)}")
        for err in errors:
            print(f"  - {err}")
    else:
        print(f"Errors:    0")
    print()
    print(f"To import in IRIS Studio:")
    print(f"  Tools > Import Local > select AIAgent-export-v{version}.xml > Open")
    print()
    print(f"To import via Terminal:")
    print(f'  do $system.OBJ.Load("{versioned_file}", "ck")')


if __name__ == "__main__":
    main()
