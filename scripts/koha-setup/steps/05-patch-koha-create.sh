#!/usr/bin/env bash
set -euo pipefail

if [ -x /usr/sbin/koha-create ]; then
  # Debian Koha templates inject AssignUserID directives by default.
  # In container mode mpm_itk is absent, so strip those directives before koha-create renders vhosts.
  for apache_tpl in /etc/koha/apache-site.conf.in /etc/koha/apache-site-https.conf.in; do
    if [ -f "${apache_tpl}" ]; then
      sed -Ei '/^[[:space:]]*AssignUserID[[:space:]].*$/d' "${apache_tpl}" || true
    fi
  done

  # In container mode we don't use mpm_itk. Bypass only the invocation point.
  if grep -Eq '^[[:space:]]*check_apache_config[[:space:]]*$' /usr/sbin/koha-create; then
    sed -Ei \
      's/^[[:space:]]*check_apache_config[[:space:]]*$/echo "WARNING: mpm_itk check bypassed (container mode)." 1>\&2/' \
      /usr/sbin/koha-create || true
  fi

  sed -i "s/die \"User \\\$username already exists\\.\"/echo \"User exists.\" 1>\\&2/" /usr/sbin/koha-create || true
  sed -i "s/die \"Group \\\$username already exists\\.\"/echo \"Group exists.\" 1>\\&2/" /usr/sbin/koha-create || true
fi
