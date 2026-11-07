"""Run the whole pipeline: build warehouse -> quality checks -> export for Power BI."""
import sys

import build_warehouse
import export_for_powerbi
import quality_checks


def main() -> int:
    print("[1/3] Building warehouse")
    build_warehouse.build()

    print("\n[2/3] Running data quality checks")
    if not quality_checks.run():
        print("\nA FAIL check did not pass. Export skipped.")
        return 1

    print("\n[3/3] Exporting for Power BI")
    export_for_powerbi.export()
    print("\nDone. Load the files in data/exports/ into Power BI.")
    return 0


if __name__ == "__main__":
    sys.exit(main())