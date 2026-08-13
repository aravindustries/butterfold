from __future__ import annotations

import argparse

from butterfold_sim.report import run_full_report, run_milestone_report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="ButterFold software proof-of-concept simulator")
    parser.add_argument(
        "--full",
        action="store_true",
        help="Run the full SCS/m/k sweep and print a complete pass/fail table",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    print(run_milestone_report())
    if args.full:
        print("\nFull sweep results:")
        print(run_full_report())


if __name__ == "__main__":
    main()
