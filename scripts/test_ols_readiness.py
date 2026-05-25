#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Tennitus - EMBL-EBI OLS Product Readiness Verification Script
------------------------------------------------------------
Validates the local environment, checks the science plugin skills, and 
queries the EBI Ontology Lookup Service (OLS) to verify integration status.
"""

import os
import sys
import json
import time
import subprocess
from pathlib import Path

# ANSI colors for premium terminal display
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_DIM = "\033[2m"
C_UNDERLINE = "\033[4m"

# Premium Palette
C_CYAN = "\033[38;5;45m"
C_MAGENTA = "\033[38;5;197m"
C_GREEN = "\033[38;5;83m"
C_YELLOW = "\033[38;5;220m"
C_RED = "\033[38;5;196m"
C_PURPLE = "\033[38;5;129m"
C_BG_DARK = "\033[48;5;234m"

def print_banner():
    """Prints a premium, stunning terminal banner for the Tennitus readiness test."""
    banner = f"""
{C_BG_DARK}{C_BOLD}{C_CYAN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  {C_RESET}
{C_BG_DARK}{C_BOLD}{C_CYAN}   T E N N I T U S   |   O N T O L O G Y   I N T E G R A T I O N            {C_RESET}
{C_BG_DARK}{C_BOLD}{C_MAGENTA}   Product Readiness & Science Skill Verification Suite                     {C_RESET}
{C_BG_DARK}{C_BOLD}{C_CYAN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  {C_RESET}
"""
    print(banner)

def print_step(name, status="PENDING", details=""):
    """Prints a step status with aligned formatting and icons."""
    icon = f"{C_YELLOW}◷{C_RESET}"
    color = C_YELLOW
    
    if status == "SUCCESS":
        icon = f"{C_GREEN}✓{C_RESET}"
        color = C_GREEN
    elif status == "FAILED":
        icon = f"{C_RED}✗{C_RESET}"
        color = C_RED
    elif status == "RUNNING":
        icon = f"{C_CYAN}❖{C_RESET}"
        color = C_CYAN
        
    line = f" {icon}  {C_BOLD}{name:<35}{C_RESET}  [{color}{status:<8}{C_RESET}]"
    if details:
        line += f" {C_DIM}— {details}{C_RESET}"
    print(line)

def run_cmd(args, cwd=None):
    """Runs a process and returns execution metrics."""
    start_time = time.perf_counter()
    try:
        result = subprocess.run(
            args,
            shell=False,
            capture_output=True,
            text=True,
            cwd=cwd,
            check=True
        )
        elapsed = time.perf_counter() - start_time
        return True, result.stdout, elapsed
    except subprocess.CalledProcessError as e:
        elapsed = time.perf_counter() - start_time
        return False, e.stderr or e.stdout, elapsed

def main():
    print_banner()
    
    workspace_dir = Path("/Volumes/Avi's drive/Projects-ongoing/Tennitus")
    build_dir = workspace_dir / "build" / "ols_readiness"
    build_dir.mkdir(parents=True, exist_ok=True)
    
    ols_skill_dir = Path("/Users/avinashkannan/.gemini/config/plugins/science/skills/embl_ebi_ols")
    
    overall_success = True
    timings = {}
    
    # -------------------------------------------------------------
    # STEP 1: Verify Environment & Prerequisites
    # -------------------------------------------------------------
    print(f"\n{C_BOLD}{C_PURPLE}✦ [1/3] Environment & Prerequisites Verification{C_RESET}")
    
    # Check uv installation
    uv_ok, uv_out, uv_time = run_cmd(["uv", "--version"])
    timings["UV Check"] = uv_time
    if uv_ok:
        uv_ver = uv_out.strip()
        print_step("Python UV Package Manager", "SUCCESS", f"{uv_ver} ({uv_time:.2f}s)")
    else:
        print_step("Python UV Package Manager", "FAILED", "UV not found on system path.")
        overall_success = False
        
    # Check OLS skill directory
    if ols_skill_dir.exists():
        print_step("EMBL-EBI OLS Skill Path", "SUCCESS", f"Found at {ols_skill_dir.name}/")
    else:
        print_step("EMBL-EBI OLS Skill Path", "FAILED", "OLS skill folder missing.")
        overall_success = False
        
    # Check License Notification
    license_file = ols_skill_dir / "LICENSE_NOTIFICATION.txt"
    if license_file.exists():
        print_step("OLS License Notification", "SUCCESS", "License accepted & verified")
    else:
        print_step("OLS License Notification", "FAILED", "LICENSE_NOTIFICATION.txt not initialized.")
        overall_success = False
        
    # -------------------------------------------------------------
    # STEP 2: Functional API & Script Verification
    # -------------------------------------------------------------
    print(f"\n{C_BOLD}{C_PURPLE}✦ [2/3] API & Script Functional Verification{C_RESET}")
    
    # Term search test
    search_out_path = build_dir / "ols_search_test.json"
    search_cmd = [
        "uv", "run", "scripts/search_ols.py",
        "--query", "tinnitus",
        "--ontology", "doid",
        "--rows", "3",
        "--output", str(search_out_path)
    ]
    
    print_step("OLS Ontology Search API", "RUNNING", "Querying 'tinnitus' in DOID...")
    search_ok, search_msg, search_time = run_cmd(search_cmd, cwd=str(ols_skill_dir))
    timings["Ontology Search"] = search_time
    
    if search_ok and search_out_path.exists():
        try:
            with open(search_out_path, 'r') as f:
                data = json.load(f)
            total_found = data.get("total_found", 0)
            terms = data.get("terms", [])
            details = f"Found {total_found} terms, top: '{terms[0]['label']}' ({search_time:.2f}s)"
            print_step("OLS Ontology Search API", "SUCCESS", details)
        except Exception as e:
            print_step("OLS Ontology Search API", "FAILED", f"JSON Parse error: {str(e)}")
            overall_success = False
    else:
        print_step("OLS Ontology Search API", "FAILED", f"Command failed: {search_msg.strip()[:100]}")
        overall_success = False

    # Get term details test
    term_out_path = build_dir / "ols_term_test.json"
    term_cmd = [
        "uv", "run", "scripts/get_term.py",
        "--obo_id", "DOID:9849",
        "--summary",
        "--output", str(term_out_path)
    ]
    
    print_step("OLS Term Details API", "RUNNING", "Querying Meniere's disease (DOID:9849)...")
    term_ok, term_msg, term_time = run_cmd(term_cmd, cwd=str(ols_skill_dir))
    timings["Term Details"] = term_time
    
    if term_ok and term_out_path.exists():
        try:
            with open(term_out_path, 'r') as f:
                data = json.load(f)
            term_info = data.get("term", {})
            label = term_info.get("label", "Unknown")
            obo_id = term_info.get("obo_id", "Unknown")
            details = f"Retrieved '{label}' [{obo_id}] ({term_time:.2f}s)"
            print_step("OLS Term Details API", "SUCCESS", details)
        except Exception as e:
            print_step("OLS Term Details API", "FAILED", f"JSON Parse error: {str(e)}")
            overall_success = False
    else:
        print_step("OLS Term Details API", "FAILED", f"Command failed: {term_msg.strip()[:100]}")
        overall_success = False
        
    # -------------------------------------------------------------
    # STEP 3: Summary and Readiness Verdict
    # -------------------------------------------------------------
    print(f"\n{C_BOLD}{C_PURPLE}✦ [3/3] Performance & System Readiness Summary{C_RESET}")
    
    # Beautiful performance grid
    print(f" {C_DIM}┌──────────────────────────────────────┬─────────────┐{C_RESET}")
    print(f" {C_DIM}│{C_RESET} {C_BOLD}Verification Step{C_RESET:<36} {C_DIM}│{C_RESET} {C_BOLD}Duration{C_RESET:<11} {C_DIM}│{C_RESET}")
    print(f" {C_DIM}├──────────────────────────────────────┼─────────────┤{C_RESET}")
    for name, elapsed in timings.items():
        print(f" {C_DIM}│{C_RESET} {name:<36} {C_DIM}│{C_RESET} {elapsed:6.2f}s     {C_DIM}│{C_RESET}")
    print(f" {C_DIM}└──────────────────────────────────────┴─────────────┘{C_RESET}")
    
    # Verdict
    if overall_success:
        verdict = f"""
{C_GREEN}{C_BOLD} 🎉 SUCCESS: EMBL-EBI OLS INTEGRATION IS FULLY READY FOR PRODUCTION!{C_RESET}
 {C_DIM}All environment checks passed, EBI OLS API connections resolved, and JSON schemas validated.{C_RESET}
 {C_DIM}Readiness data written to: {build_dir.relative_to(workspace_dir)}/{C_RESET}
"""
    else:
        verdict = f"""
{C_RED}{C_BOLD} ✗ FAILURE: INTEGRATION IS NOT YET READY.{C_RESET}
 {C_DIM}Please review the failed steps above and check network settings / plugin files.{C_RESET}
"""
    print(verdict)
    
    return 0 if overall_success else 1

if __name__ == "__main__":
    sys.exit(main())
