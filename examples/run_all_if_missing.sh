#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLES_DIR="${SCRIPT_DIR}"
DRY_RUN=1

print_usage() {
  local bin
  bin="$(basename "$0")"
  echo "Usage: ${bin} [--dry|--dry-run] [--run] [-h|--help]"
  echo "Default mode: --dry (preview only, no generation)."
  echo "Run real generation: ${bin} --run"
}

count_mode_videos() {
  local dir="$1"
  local mode="$2"
  shopt -s nullglob
  local files=("${dir}"/*.mp4)
  shopt -u nullglob
  local count=0
  local file
  for file in "${files[@]}"; do
    local base
    base="$(basename "${file}")"
    if [[ "${mode}" == "aligncache" ]]; then
      [[ "${base}" == *aligncache* ]] && ((count+=1))
    else
      [[ "${base}" != *aligncache* ]] && ((count+=1))
    fi
  done
  echo "${count}"
}

run_if_missing() {
  local example_dir="$1"
  local script_name="$2"
  local mode="$3"
  local video_mode="$4"
  local log_name="$5"

  local script_path="${example_dir}/${script_name}"
  if [[ ! -f "${script_path}" ]]; then
    echo "[skip] $(basename "${example_dir}") missing ${script_name}"
    return 0
  fi

  local existing_count
  existing_count="$(count_mode_videos "${example_dir}" "${video_mode}")"
  if [[ "${existing_count}" -gt 0 ]]; then
    echo "[skip] $(basename "${example_dir}") already has ${mode} video (${existing_count})"
    return 0
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[dry ] $(basename "${example_dir}") would run ${script_name} -> ${log_name}"
    return 0
  fi

  echo "[run ] $(basename "${example_dir}") ${mode}"
  (
    cd "${example_dir}" || exit 1
    bash "./${script_name}" > "${log_name}" 2>&1
  )
  local status=$?
  if [[ "${status}" -ne 0 ]]; then
    echo "[fail] $(basename "${example_dir}") ${mode} (see ${log_name})"
    return "${status}"
  fi
  echo "[done] $(basename "${example_dir}") ${mode}"
}

main() {
  print_usage
  echo

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --dry|--dry-run)
        DRY_RUN=1
        ;;
      --run)
        DRY_RUN=0
        ;;
      -h|--help)
        print_usage
        return 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        print_usage >&2
        return 2
        ;;
    esac
    shift
  done

  local failed=0
  shopt -s nullglob
  local dirs=("${EXAMPLES_DIR}"/*)
  shopt -u nullglob

  for dir in "${dirs[@]}"; do
    [[ -d "${dir}" ]] || continue
    [[ -f "${dir}/prompt.txt" ]] || continue

    run_if_missing "${dir}" "run_full_DiT.sh" "full DiT" "full" "run_full_DiT.log" || failed=1
    run_if_missing "${dir}" "run_aligncache.sh" "AlignCache" "aligncache" "run_aligncache.log" || failed=1
  done

  if [[ "${failed}" -ne 0 ]]; then
    echo "Completed with failures."
    return 1
  fi
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "Dry run completed. Use --run to execute generation."
  else
    echo "Completed successfully."
  fi
}

main "$@"
