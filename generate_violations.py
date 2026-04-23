import openpyxl
import os

def generate_dart_violations():
    try:
        wb = openpyxl.load_workbook('errordata.xlsx', read_only=True, data_only=True)
        ws = wb.active
        
        violations = []
        # Skip header row (min_row=2)
        for row in ws.iter_rows(min_row=2, values_only=True):
            if not row or not row[0]: continue
            
            text = str(row[0]).strip().replace("'", "\\'").replace('"', '\\"')
            level = row[1] if row[1] is not None else 1
            deduction = row[2] if row[2] is not None else 1
            
            violations.append(f"  BehaviorViolationType(text: '{text}', level: {level}, deduction: {deduction}),")

        # Write to Dart file
        # Ensure directory exists
        output_dir = os.path.join('lib', 'src', 'features', 'behavior', 'data')
        os.makedirs(output_dir, exist_ok=True)
        output_path = os.path.join(output_dir, 'violation_data.dart')
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write("import '../domain/models/behavior_violation_type.dart';\n\n")
            f.write("const List<BehaviorViolationType> predefinedViolations = [\n")
            for v in violations:
                f.write(v + "\n")
            f.write("];\n")
            
        print(f"Successfully generated {len(violations)} violations in {output_path}")
        
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    generate_dart_violations()
