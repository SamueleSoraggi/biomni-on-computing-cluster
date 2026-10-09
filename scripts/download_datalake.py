"""Download Biomni's data lake (~11 GB) and benchmark files once, without needing an LLM key.

Produces the layout A1(path=...) expects:  <path>/biomni_data/{data_lake,benchmark}
so later jobs start instantly and never download concurrently.

    biomni-exec python scripts/download_datalake.py [--path DIR] [--no-benchmark]
"""

import argparse
import os
import sys

from biomni.env_desc import data_lake_dict
from biomni.utils import check_and_download_s3_files

S3 = "https://biomni-release.s3.amazonaws.com"

parser = argparse.ArgumentParser()
parser.add_argument("--path", default=os.environ.get("BIOMNI_DATA_PATH", "./data"))
parser.add_argument("--no-benchmark", action="store_true")
args = parser.parse_args()

data_lake_dir = os.path.join(args.path, "biomni_data", "data_lake")
benchmark_dir = os.path.join(args.path, "biomni_data", "benchmark")
os.makedirs(benchmark_dir, exist_ok=True)

print(f"Data lake -> {data_lake_dir}")
results = check_and_download_s3_files(S3, data_lake_dir, list(data_lake_dict.keys()), folder="data_lake")

if not args.no_benchmark and not os.path.isdir(os.path.join(benchmark_dir, "hle")):
    print(f"Benchmark -> {benchmark_dir}")
    check_and_download_s3_files(S3, benchmark_dir, [], folder="benchmark")

missing = [f for f in data_lake_dict if not os.path.exists(os.path.join(data_lake_dir, f))]
print(f"{len(data_lake_dict) - len(missing)}/{len(data_lake_dict)} data lake files present")
if missing:
    print("Missing:", *missing, sep="\n  ")
    sys.exit(1)
