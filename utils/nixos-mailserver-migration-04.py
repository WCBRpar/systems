#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages (ps: with ps; [ ldap3 ])"

import argparse
import os
import sys
from pathlib import Path
from pwd import getpwnam
from typing import Literal, cast

from ldap3 import BASE, LEVEL, SUBTREE, Connection, Server
from ldap3.core.exceptions import LDAPException

LDAPSearchScope = Literal["BASE", "LEVEL", "SUBTREE"]

EXIT_OK = 0
EXIT_ERROR = 1
EXIT_LDAP_STARTTLS = 2
EXIT_LDAP_BIND = 3

GREEN = "32"
YELLOW = "33"
RED = "31"
BOLD = "1"

NO_COLOR = "NO_COLOR" in os.environ


def color(text, code):
    if NO_COLOR:
        return text
    return f"\033[{code}m{text}\033[0m"


def check_user(vmail_root: Path):
    owner = vmail_root.owner()
    owner_uid = getpwnam(owner).pw_uid

    if os.geteuid() == owner_uid:
        return

    try:
        print(f"Trying to switch effective user id to {owner_uid} ({owner})")
        os.seteuid(owner_uid)
        return
    except PermissionError:
        print(
            f"Failed switching to virtual mail user. Please run this script under it, for example by using `sudo -u {owner}`)"
        )
    sys.exit(1)


def move(*, src: Path, dst: Path, dry_run: bool = True) -> bool:
    print(f'mv "{src}" "{dst}"')
    if not dry_run:
        try:
            src.rename(dst)
        except OSError as exc:
            print(f"Rename failed ({src=!s}, {dst=!s}): {exc}")
            return False
    return True


def main(
    *,
    vmail_root: Path,
    ldap_uri: str,
    ldap_starttls: bool,
    ldap_bind_dn: str,
    ldap_bind_pw: str,
    ldap_base: str,
    ldap_scope: LDAPSearchScope,
    ldap_filter: str,
    ldap_attr_uuid: str,
    dry_run: bool = True,
    verbose: bool = False,
):
    # Begin with LDAP connection for fast feedback
    server = Server(ldap_uri)
    conn = Connection(server, ldap_bind_dn, ldap_bind_pw)

    if ldap_starttls:
        try:
            if ldap_starttls:
                conn.start_tls()
        except LDAPException as exc:
            print(color(f"LDAP connection setup failed: {exc!r}", RED))
            sys.exit(EXIT_LDAP_STARTTLS)

    if not conn.bind():
        err = conn.result
        print(
            color(
                f"""
LDAP bind failed for {ldap_bind_dn}@{ldap_uri}
Result: {err.get("result")} ({err.get("description")})
Message: {err.get("message")!r}""",
                RED,
            )
        )
        sys.exit(EXIT_LDAP_BIND)

    # Find existing dovecot home directories and collect account identifier
    print(
        color(
            f"\nEnumerate accounts based on existing home directories in {(vmail_root / 'ldap')!s}",
            BOLD,
        )
    )

    skipped = 0
    accounts = set()
    homedirs = vmail_root.glob("ldap/*")
    for path in homedirs:
        if not path.is_dir():
            print(f"- Not a directory ({path=!s}) (skipping)")
            skipped += 1
            continue
        elif not (path / "mail").is_dir():
            print(f"- No maildir in home ({path=!s}) (skipping)")
            skipped += 1
            continue

        account = path.name
        accounts.add(account)
        if verbose:
            print(f"- Home directory found ({path=!s}, {account=})")

    print(
        color(
            f"\nFinding matching LDAP entries to retrieve `{ldap_attr_uuid}` attribute",
            BOLD,
        )
    )

    no_entry = 0
    multiple_entries = 0
    plan = {}
    for account in sorted(accounts):
        filter = ldap_filter % account
        conn.search(
            search_base=ldap_base,
            search_filter=filter,
            search_scope=ldap_scope,
            attributes=[ldap_attr_uuid],
        )

        if conn.response is None:
            print(f"- LDAP search produced no result for {filter}")

        count = len(conn.entries)

        if count < 1:
            print(f"- No LDAP entry found ({account=}, {filter=}) (skipping)")
            no_entry += 1
            continue
        elif count > 1:
            print(f"- Multiple LDAP entries found ({account=}, {filter=}) (skipping)")
            multiple_entries += 1
            continue
        else:
            entry = conn.entries[0]
            uuid = str(entry[ldap_attr_uuid].value)
            if verbose:
                print(f"- LDAP entry mapped ({account=}, {uuid=})")
            plan.update({account: uuid})

    print(color("\nThe following operations will be executed:", BOLD))
    moved = 0
    moves_failed = 0
    for src, dst in plan.items():
        _src = vmail_root / "ldap" / src
        _dst = vmail_root / "ldap" / dst
        if not move(src=_src, dst=_dst, dry_run=dry_run):
            moves_failed += 1
        else:
            moved += 1

    print(
        color(
            "\nMigration summary",
            BOLD,
        )
    )

    if any([skipped, no_entry, multiple_entries, not accounts, moves_failed]):
        print("""
We strongly recommend reviewing and remediating all potential issues before
running with `--execute`. Specific details can be found further up.""")

    if moved:
        print(f"""
- {color(f"{moved} home directories were migrated successfully.", GREEN)} {"(dry run)" if dry_run else ""}
  This is great news, they are now UUID-based and will be immune to username changes!""")

    if skipped and accounts:
        print(f"""
- {color(f"{skipped} paths in {(vmail_root / 'ldap')!s} were skipped.", YELLOW)}
  These were not a directory or did not contain a maildir. They should be
  reviewed but can most likely be deleted.""")

    if no_entry:
        print(f"""
- {color(f"{no_entry} LDAP queries found no entry.", YELLOW)}
  This could be a problem, because we cannot migrate home directories without
  finding the LDAP entry and retrieving its {ldap_attr_uuid} field. In practice
  this can happen if an LDAP account was deleted but its mail home directory
  remained.""")

    if multiple_entries:
        print(f"""
- {color(f"{multiple_entries} LDAP queries returned multiple entries.", RED)}
  This is a problem, because we cannot decide which LDAP entry owns the home
  directory.""")

    if not accounts:
        print(f"""
- {color("No home directories were found.", RED)}
  Make sure you are passing the correct `vmail_root` argument. It must match
  your `mailserver.mailDirectory` setting.""")

    if moves_failed:
        print(f"""
- {color("{moves_failed} home directories could not be renamed", RED)}
  No reason to panic, but the script tried to rename a home directory and that
  triggered and error. Check further up what went wrong.""")

    if dry_run:
        print(f"\n{color('No changes were made.', YELLOW)}")
        print("Run the script with `--execute` to apply the listed changes.")

    sys.exit(EXIT_OK if moves_failed == 0 else EXIT_ERROR)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="""
        NixOS Mailserver Migration #4: Dovecot LDAP UUID-based home directories
        (https://nixos-mailserver.readthedocs.io/en/latest/migrations.html#dovecot-ldap-uuid-based-home-directory)
        """
    )
    parser.add_argument(
        "vmail_root", type=Path, help="Path to the `mailserver.mailDirectory`"
    )
    parser.add_argument(
        "--ldap-uri",
        type=str,
        required=True,
        help="URI for your LDAP server; ldaps://ldap1.example.com (TLS) or ldap://ldap1.example.com (Plain)",
    )
    parser.add_argument(
        "--ldap-starttls",
        action="store_true",
        help="Enable StartTLS on plain LDAP connections",
    )
    parser.add_argument(
        "--ldap-bind-dn",
        type=str,
        required=True,
        help="The distinguished user allow to bind and search the LDAP server",
    )
    parser.add_argument(
        "--ldap-bind-pw-file",
        type=Path,
        required=True,
        help="Path to a file containing the bind password for the LDAP DN",
    )
    parser.add_argument(
        "--ldap-base",
        type=str,
        required=True,
        help="Base DN below which to search for LDAP accounts",
    )
    parser.add_argument(
        "--ldap-scope",
        choices=[
            "sub",
            "base",
            "one",
        ],
        default="sub",
        help="Scope relative to the base DN",
    )
    parser.add_argument(
        "--ldap-filter",
        default="(mail=%s)",
        help="LDAP query that filters for an account by the name in /var/vmail/ldap/<name> field, e.g. mail=%%s or uid=%%s if the name is not an email address.",
    )
    parser.add_argument(
        "--ldap-attr-uuid",
        default="entryUUID",
        help="UUID attribute that uniquely identifies an LDAP account across login name changes",
    )
    parser.add_argument(
        "--execute", action="store_true", help="Actually perform changes"
    )
    parser.add_argument("--verbose", action="store_true", help="Print more details")

    args = parser.parse_args()

    if args.ldap_filter.count("%s") != 1:
        print(
            "The --ldap-filter argument must contain exactly one '%s' as a placeholder for the primary email address.",
        )
        sys.exit(1)

    def read_ldap_bind_pw():
        try:
            with open(args.ldap_bind_pw_file) as fd:
                return fd.read().strip()
        except OSError as exc:
            print(f"Unable to read LDAP bind password file: {exc}")
            sys.exit(1)

    ldap_bind_pw = None
    if os.geteuid() == 0:
        # if we're root, read before priv drop
        ldap_bind_pw = read_ldap_bind_pw()

    check_user(args.vmail_root)

    if ldap_bind_pw is None:
        ldap_bind_pw = read_ldap_bind_pw()

    ldap_scope: LDAPSearchScope = cast(
        LDAPSearchScope,
        {
            "sub": SUBTREE,
            "base": BASE,
            "one": LEVEL,
        }[args.ldap_scope],
    )

    main(
        vmail_root=args.vmail_root,
        ldap_uri=args.ldap_uri,
        ldap_starttls=args.ldap_starttls,
        ldap_bind_dn=args.ldap_bind_dn,
        ldap_bind_pw=ldap_bind_pw,
        ldap_base=args.ldap_base,
        ldap_scope=ldap_scope,
        ldap_filter=args.ldap_filter,
        ldap_attr_uuid=args.ldap_attr_uuid,
        dry_run=not args.execute,
        verbose=args.verbose,
    )
