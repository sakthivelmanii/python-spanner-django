import re
import sys

def parse_log(log_path):
    failures = set()
    errors = set()
    exit_status_failures = set()
    
    with open(log_path, 'r') as f:
        lines = f.readlines()
    
    for i, line in enumerate(lines):
        # Standard FAIL/ERROR patterns
        if "FAIL: " in line:
            match = re.search(r"FAIL: (.*?)(?: \(|$)", line)
            if match:
                failures.add(match.group(1).strip())
        elif "ERROR: " in line:
            match = re.search(r"ERROR: (.*?)(?: \(|$)", line)
            if match:
                errors.add(match.group(1).strip())
        
        # Check for EXIT_STATUS=1
        if "EXIT_STATUS=1" in line:
            # Look at the preceding few lines for context
            # Usually the failure is 1-2 lines above
            # Example context? Users usually see a test failure right before exit.
            # We'll take the 5 preceding lines to be safe and try to find test names.
            start_index = max(0, i - 10)
            context = lines[start_index:i]
            for context_line in context:
                # heuristic: looks like a test path
                # e.g. "model_fields.test_uuid.TestQuerying.test_iexact"
                # But sometimes it's just "FAIL: test_name"
                if "FAIL" in context_line or "ERROR" in context_line:
                     match = re.search(r"(?:FAIL|ERROR): (.*?)(?: \(|$)", context_line)
                     if match:
                        exit_status_failures.add(match.group(1).strip())

    print(f"Found {len(failures)} failures.")
    print(f"Found {len(errors)} errors.")
    print(f"Found {len(exit_status_failures)} failures near EXIT_STATUS=1.")
    
    all_failures = failures.union(errors).union(exit_status_failures)
    
    print("\nAll Unique Failures:")
    for failure in sorted(list(all_failures)):
        print(failure)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 parse_ci_log_final.py <log_file>")
        sys.exit(1)
    parse_log(sys.argv[1])
