#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_dir="$(cd "${script_dir}/.." && pwd)"
source_dir="${repo_dir}/images/favorites"
thumb_dir="${source_dir}/webp/thumbs"
full_dir="${source_dir}/webp/full"

for required_command in cwebp sips; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Required command not found: ${required_command}" >&2
    exit 1
  fi
done

mkdir -p "${thumb_dir}" "${full_dir}"

encode_webp() {
  local source_path="$1"
  local output_path="$2"
  local source_width="$3"
  local source_height="$4"
  local max_dimension="$5"
  local quality="$6"
  local resize_args=()

  if (( source_width > max_dimension || source_height > max_dimension )); then
    if (( source_width >= source_height )); then
      resize_args=(-resize "${max_dimension}" 0)
    else
      resize_args=(-resize 0 "${max_dimension}")
    fi
  fi

  cwebp -quiet -mt -q "${quality}" -metadata icc \
    "${resize_args[@]}" "${source_path}" -o "${output_path}"
}

converted_count=0
while IFS= read -r -d '' source_path; do
  filename="$(basename "${source_path}")"
  stem="${filename%.*}"
  source_width="$(sips -g pixelWidth "${source_path}" | awk '/pixelWidth:/ {print $2}')"
  source_height="$(sips -g pixelHeight "${source_path}" | awk '/pixelHeight:/ {print $2}')"
  thumb_path="${thumb_dir}/${stem}.webp"
  full_path="${full_dir}/${stem}.webp"

  if [[ ! -f "${thumb_path}" || "${source_path}" -nt "${thumb_path}" ]]; then
    encode_webp "${source_path}" "${thumb_path}" "${source_width}" "${source_height}" 1600 82
  fi

  if [[ ! -f "${full_path}" || "${source_path}" -nt "${full_path}" ]]; then
    encode_webp "${source_path}" "${full_path}" "${source_width}" "${source_height}" 2560 85
  fi

  converted_count=$((converted_count + 1))
  printf '\rProcessed %d JPG files' "${converted_count}"
done < <(find "${source_dir}" -maxdepth 1 -type f -iname '*.jpg' -print0 | sort -z)

printf '\nWebP output written to:\n  %s\n  %s\n' "${thumb_dir}" "${full_dir}"
