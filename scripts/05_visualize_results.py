#!/usr/bin/env python3
"""
05_visualize_results.py
────────────────────────
Generate publication-quality figures for both Track A (structural)
and Track B (functional) analyses.

Outputs (saved to outputs/figures/):
  structural_roi_comparison.png   — grouped bar chart, ROI volumes/thickness
  structural_effect_sizes.png     — Cohen's d forest plot
  fc_group_difference.png         — FC matrix group difference heatmap
  pcc_seed_map.png                — PCC seed connectivity brain map
  summary_table.csv               — combined results summary
"""
import os, warnings
from pathlib import Path

import numpy  as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

warnings.filterwarnings("ignore")

# ── Paths ──────────────────────────────────────────────────────────────────────
PROJ_DIR   = Path(__file__).resolve().parent.parent
ANA_DIR    = PROJ_DIR / "outputs" / "analysis"
FIG_DIR    = PROJ_DIR / "outputs" / "figures"
FIG_DIR.mkdir(parents=True, exist_ok=True)

STRUCT_CSV  = ANA_DIR / "structural" / "group_comparison_structural.csv"
FEAT_CSV    = ANA_DIR / "structural" / "subject_features.csv"
FC_HEAVY    = ANA_DIR / "functional" / "fc_heavy.npy"
FC_CTRL     = ANA_DIR / "functional" / "fc_control.npy"
P_FDR_MAP   = ANA_DIR / "functional" / "p_fdr_map.npy"
T_MAP       = ANA_DIR / "functional" / "t_map.npy"
PCC_CSV     = ANA_DIR / "functional" / "pcc_seed_connectivity.csv"

COLORS = {"heavy": "#C0392B", "control": "#2980B9"}
ALPHA  = 0.7

# ═══════════════════════════════════════════════════════════════════════════════
# TRACK A — Structural Figures
# ═══════════════════════════════════════════════════════════════════════════════
if STRUCT_CSV.exists():
    print("[viz] Generating structural figures ...")
    res_df = pd.read_csv(STRUCT_CSV)

    # ── 1. ROI bar chart (top 12 by effect size) ─────────────────────────────
    plot_df = res_df.nlargest(12, "cohens_d").copy()
    plot_df["roi_short"] = plot_df["roi"].str.replace(
        r"(Left-|Right-|lh_|rh_)", "", regex=True
    ).str.replace("-", "\n").str[:20]

    fig, ax = plt.subplots(figsize=(14, 6))
    x  = np.arange(len(plot_df))
    w  = 0.35

    bars1 = ax.bar(x - w/2, plot_df["mean_heavy"],   w,
                   yerr=plot_df["std_heavy"],
                   label="Heavy Users", color=COLORS["heavy"],
                   alpha=ALPHA, capsize=4, error_kw={"linewidth":1.2})
    bars2 = ax.bar(x + w/2, plot_df["mean_control"], w,
                   yerr=plot_df["std_control"],
                   label="Controls", color=COLORS["control"],
                   alpha=ALPHA, capsize=4, error_kw={"linewidth":1.2})

    # Significance markers
    for i, (_, row) in enumerate(plot_df.iterrows()):
        if row.get("sig_fdr05", False):
            ymax = max(row["mean_heavy"] + row["std_heavy"],
                       row["mean_control"] + row["std_control"])
            ax.text(x[i], ymax * 1.03, "*", ha="center", fontsize=14,
                    color="#333333")

    ax.set_xticks(x)
    ax.set_xticklabels(plot_df["roi_short"], fontsize=8, rotation=30, ha="right")
    ax.set_ylabel("Volume (mm³) / Thickness (mm)", fontsize=11)
    ax.set_title("Top ROIs by Effect Size — Heavy Users vs Controls\n"
                 "(* = FDR q<0.05, error bars = 1 SD)", fontsize=12)
    ax.legend(fontsize=10)
    ax.spines[["top","right"]].set_visible(False)
    fig.tight_layout()
    fig.savefig(FIG_DIR / "structural_roi_comparison.png", dpi=150)
    plt.close(fig)
    print("[viz]   ✓ structural_roi_comparison.png")

    # ── 2. Cohen's d forest plot ─────────────────────────────────────────────
    fplot_df = res_df.sort_values("cohens_d", ascending=True).tail(20)
    fig, ax  = plt.subplots(figsize=(8, 9))

    colors_bar = [COLORS["heavy"] if d > 0 else COLORS["control"]
                  for d in fplot_df["cohens_d"]]
    y = np.arange(len(fplot_df))
    ax.barh(y, fplot_df["cohens_d"], color=colors_bar, alpha=ALPHA)
    ax.axvline(0, color="black", linewidth=0.8)
    ax.set_yticks(y)
    ax.set_yticklabels(fplot_df["roi"].str.replace("Left-|Right-|lh_|rh_", "",
                                                    regex=True), fontsize=8)
    ax.set_xlabel("Cohen's d  (positive = larger in heavy users)", fontsize=10)
    ax.set_title("Effect Sizes — Structural Group Differences\n"
                 "(top 20 ROIs)", fontsize=12)

    heavy_p  = mpatches.Patch(color=COLORS["heavy"],  alpha=ALPHA, label="Larger in heavy users")
    ctrl_p   = mpatches.Patch(color=COLORS["control"], alpha=ALPHA, label="Larger in controls")
    ax.legend(handles=[heavy_p, ctrl_p], fontsize=9)
    ax.spines[["top","right"]].set_visible(False)
    fig.tight_layout()
    fig.savefig(FIG_DIR / "structural_effect_sizes.png", dpi=150)
    plt.close(fig)
    print("[viz]   ✓ structural_effect_sizes.png")

else:
    print("[viz] No structural results found — skipping Track A figures")
    print("     Run: python scripts/04_structural_analysis.py")


# ═══════════════════════════════════════════════════════════════════════════════
# TRACK B — Functional Figures
# ═══════════════════════════════════════════════════════════════════════════════
if FC_HEAVY.exists() and FC_CTRL.exists():
    print("[viz] Generating functional connectivity figures ...")

    fc_heavy = np.load(FC_HEAVY)
    fc_ctrl  = np.load(FC_CTRL)
    mean_h   = np.mean(fc_heavy, axis=0)
    mean_c   = np.mean(fc_ctrl,  axis=0)
    diff     = mean_h - mean_c

    # ── 3. FC group difference heatmap ───────────────────────────────────────
    fig, axes = plt.subplots(1, 3, figsize=(16, 5))
    titles    = ["Heavy Users (mean FC)",
                 "Controls (mean FC)",
                 "Difference (Heavy − Control)"]
    maps_     = [mean_h, mean_c, diff]
    cmaps_    = ["RdBu_r", "RdBu_r", "coolwarm"]

    for ax, data, title, cmap in zip(axes, maps_, titles, cmaps_):
        vmax = np.percentile(np.abs(data), 95)
        im   = ax.imshow(data, cmap=cmap, vmin=-vmax, vmax=vmax,
                         aspect="auto", interpolation="nearest")
        ax.set_title(title, fontsize=10)
        ax.set_xlabel("ROI index"); ax.set_ylabel("ROI index")
        plt.colorbar(im, ax=ax, fraction=0.046, pad=0.04)

    # Overlay significant pairs on difference map
    if P_FDR_MAP.exists() and T_MAP.exists():
        p_fdr = np.load(P_FDR_MAP)
        sig   = p_fdr < 0.05
        r, c  = np.where(sig)
        axes[2].scatter(c, r, s=0.5, c="black", alpha=0.4)
        axes[2].set_title(
            f"Difference (Heavy − Control)\n{int(np.sum(sig)//2)} sig. pairs, FDR q<0.05",
            fontsize=9
        )

    fig.suptitle("Whole-Brain Functional Connectivity — Cannabis Study", fontsize=12)
    fig.tight_layout()
    fig.savefig(FIG_DIR / "fc_group_difference.png", dpi=150)
    plt.close(fig)
    print("[viz]   ✓ fc_group_difference.png")

    # ── 4. PCC seed connectivity bar chart ───────────────────────────────────
    if PCC_CSV.exists():
        pcc_df = pd.read_csv(PCC_CSV).head(15)
        fig, ax = plt.subplots(figsize=(12, 6))
        x = np.arange(len(pcc_df)); w = 0.35
        ax.bar(x - w/2, pcc_df["mean_heavy_pcc"], w,
               color=COLORS["heavy"],   alpha=ALPHA, label="Heavy Users")
        ax.bar(x + w/2, pcc_df["mean_ctrl_pcc"],  w,
               color=COLORS["control"], alpha=ALPHA, label="Controls")

        for i, (_, row) in enumerate(pcc_df.iterrows()):
            if row["p_fdr_pcc"] < 0.05:
                ymax = max(row["mean_heavy_pcc"], row["mean_ctrl_pcc"])
                ax.text(x[i], ymax + 0.02, "*", ha="center", fontsize=12)

        ax.set_xticks(x)
        ax.set_xticklabels(
            pcc_df["parcel_label"].str.split("_").str[-1].str[:18],
            rotation=40, ha="right", fontsize=8
        )
        ax.set_ylabel("PCC Functional Connectivity (z-score)", fontsize=10)
        ax.set_title(
            "Posterior Cingulate Cortex Seed Connectivity\n"
            "Top 15 Regions — Heavy Users vs Controls (* = FDR q<0.05)",
            fontsize=11
        )
        ax.legend(fontsize=10)
        ax.spines[["top","right"]].set_visible(False)
        fig.tight_layout()
        fig.savefig(FIG_DIR / "pcc_seed_map.png", dpi=150)
        plt.close(fig)
        print("[viz]   ✓ pcc_seed_map.png")

else:
    print("[viz] No functional results found — skipping Track B figures")
    print("     Run: python scripts/04_functional_analysis.py")


# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY TABLE
# ═══════════════════════════════════════════════════════════════════════════════
summaries = []
if STRUCT_CSV.exists():
    s = pd.read_csv(STRUCT_CSV)
    s["analysis"] = "structural"
    summaries.append(s[["analysis","roi","mean_heavy","mean_control",
                         "cohens_d","p_uncorrected",
                         "p_fdr" if "p_fdr" in s.columns else "p_uncorrected"]])

if summaries:
    pd.concat(summaries).to_csv(FIG_DIR / "summary_table.csv", index=False)
    print("[viz]   ✓ summary_table.csv")

print(f"\n[viz] ✅ All figures saved to: {FIG_DIR}")
print("[viz] Files:")
for f in sorted(FIG_DIR.iterdir()):
    print(f"  {f.name}")
