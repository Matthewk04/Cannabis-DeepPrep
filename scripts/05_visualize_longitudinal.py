#!/usr/bin/env python3
"""
05_visualize_longitudinal.py
─────────────────────────────
Visualizations for cannabis vs control longitudinal structural analysis.

Generates:
  1. Forest plot of effect sizes (Cohen's d) for all ROIs
  2. Subject trajectory plots (BL → FU per subject) - faceted by ROI
  3. Group mean change comparison with error bars
  4. Bivariate scatter (BL vs FU) showing slope differences
  5. Summary table figure
"""

import warnings
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

warnings.filterwarnings("ignore")

# ── Paths ─────────────────────────────────────────────────────────────
PROJ_DIR = Path(__file__).resolve().parent.parent
ANA_DIR = PROJ_DIR / "outputs" / "analysis" / "structural"
FIG_DIR = PROJ_DIR / "outputs" / "figures"
FIG_DIR.mkdir(parents=True, exist_ok=True)

# ── Load data ─────────────────────────────────────────────────────────
long_df = pd.read_csv(ANA_DIR / "longitudinal_change.csv")
subj_df = pd.read_csv(ANA_DIR / "subject_features_all.csv")

print(f"[viz] Loaded {len(long_df)} ROIs, {len(subj_df)} subjects")

COLORS = {
    "heavy": "#C0392B",
    "control": "#2980B9",
    "neutral": "#7F8C8D",
}

# Categorize ROIs for nicer plotting
SUBCORTICAL_ROIS = [r for r in long_df["roi"] if any(
    s in r for s in ["Hippocampus", "Amygdala", "Caudate", "Putamen", "Accumbens"]
)]
CORTICAL_ROIS = [r for r in long_df["roi"] if r not in SUBCORTICAL_ROIS]


def clean_roi_name(roi):
    """Turn 'Left-Hippocampus' into 'Hippocampus (L)'"""
    if roi.startswith("Left-"):
        return roi[5:].replace("-", " ") + " (L)"
    if roi.startswith("Right-"):
        return roi[6:].replace("-", " ") + " (R)"
    if roi.startswith("lh_"):
        return roi[3:].replace("_", " ") + " (L)"
    if roi.startswith("rh_"):
        return roi[3:].replace("_", " ") + " (R)"
    return roi


# ═══════════════════════════════════════════════════════════════════════
# FIGURE 1: Forest plot of effect sizes — sorted by absolute d
# ═══════════════════════════════════════════════════════════════════════
print("[viz] Figure 1: Forest plot of effect sizes...")

fig, axes = plt.subplots(1, 2, figsize=(14, 7), gridspec_kw={'wspace': 0.4})

for ax, rois, title in [
    (axes[0], SUBCORTICAL_ROIS, "Subcortical Volumes"),
    (axes[1], CORTICAL_ROIS, "Cortical Thickness"),
]:
    sub = long_df[long_df["roi"].isin(rois)].copy()
    sub = sub.sort_values("cohens_d_change", ascending=True)
    
    y_pos = np.arange(len(sub))
    colors = [COLORS["heavy"] if d < 0 else COLORS["control"] 
              for d in sub["cohens_d_change"]]
    
    ax.barh(y_pos, sub["cohens_d_change"], color=colors, alpha=0.75, edgecolor="black", linewidth=0.5)
    ax.axvline(0, color="black", linewidth=1)
    ax.axvline(-0.5, color="gray", linewidth=0.5, linestyle="--", alpha=0.5)
    ax.axvline(0.5, color="gray", linewidth=0.5, linestyle="--", alpha=0.5)
    ax.axvline(-0.8, color="gray", linewidth=0.5, linestyle=":", alpha=0.5)
    ax.axvline(0.8, color="gray", linewidth=0.5, linestyle=":", alpha=0.5)
    
    ax.set_yticks(y_pos)
    ax.set_yticklabels([clean_roi_name(r) for r in sub["roi"]], fontsize=9)
    ax.set_xlabel("Cohen's d (change score)", fontsize=11)
    ax.set_title(f"{title}\n(BL → FU change comparison)", fontsize=12, pad=15)
    
    # Annotate p-values
    for i, (_, row) in enumerate(sub.iterrows()):
        x = row["cohens_d_change"]
        p = row["p_groups"]
        text_x = x + (0.15 if x >= 0 else -0.15)
        ha = 'left' if x >= 0 else 'right'
        sig_marker = " *" if p < 0.05 else ""
        ax.text(text_x, i, f"p={p:.3f}{sig_marker}", 
                va='center', ha=ha, fontsize=8, color='#333')
    
    ax.set_xlim(-2.5, 2.5)
    ax.spines[['top', 'right']].set_visible(False)
    
heavy_p = mpatches.Patch(color=COLORS["heavy"], alpha=0.75, 
                          label="Heavy users showed greater decline / less growth")
ctrl_p = mpatches.Patch(color=COLORS["control"], alpha=0.75,
                         label="Heavy users showed less decline / more growth")
fig.legend(handles=[heavy_p, ctrl_p], loc="upper center", ncol=2,
           bbox_to_anchor=(0.5, 0.03), fontsize=10, frameon=False)

fig.suptitle("Cannabis Users (n=5) vs Controls (n=5): Longitudinal Brain Change",
             fontsize=14, fontweight='bold', y=1.02)
fig.tight_layout()
fig.savefig(FIG_DIR / "01_forest_plot.png", dpi=150, bbox_inches='tight')
plt.close(fig)
print(f"  ✓ {FIG_DIR}/01_forest_plot.png")


# ═══════════════════════════════════════════════════════════════════════
# FIGURE 2: Subject trajectory plots for top 6 ROIs by |d|
# ═══════════════════════════════════════════════════════════════════════
print("[viz] Figure 2: Subject trajectory plots (top 6 ROIs)...")

top6 = long_df.reindex(long_df["cohens_d_change"].abs().sort_values(ascending=False).index).head(6)

fig, axes = plt.subplots(2, 3, figsize=(15, 9))
axes = axes.flatten()

for ax, (_, row) in zip(axes, top6.iterrows()):
    roi = row["roi"]
    bl_col = f"{roi}_BL"
    fu_col = f"{roi}_FU"
    
    if bl_col not in subj_df.columns or fu_col not in subj_df.columns:
        ax.set_visible(False)
        continue
    
    # Plot each subject as connected line
    for _, s in subj_df.iterrows():
        color = COLORS[s["group"]]
        ax.plot([0, 1], [s[bl_col], s[fu_col]], 
                color=color, alpha=0.6, linewidth=1.5, marker='o', markersize=5)
    
    # Plot group means as thick lines
    for grp in ["heavy", "control"]:
        grp_df = subj_df[subj_df["group"] == grp]
        bl_mean = grp_df[bl_col].mean()
        fu_mean = grp_df[fu_col].mean()
        ax.plot([0, 1], [bl_mean, fu_mean], 
                color=COLORS[grp], linewidth=4, marker='o', markersize=10,
                markeredgecolor='black', markeredgewidth=1.5,
                label=f"{grp} (mean)", zorder=10)
    
    # Determine units
    is_volume = roi in SUBCORTICAL_ROIS
    unit = "mm³" if is_volume else "mm"
    
    ax.set_xticks([0, 1])
    ax.set_xticklabels(["Baseline", "Follow-up\n(3yr)"], fontsize=10)
    ax.set_ylabel(f"{clean_roi_name(roi)} ({unit})", fontsize=10)
    ax.set_title(f"{clean_roi_name(roi)}\n"
                 f"d={row['cohens_d_change']:.2f}, p={row['p_groups']:.3f}",
                 fontsize=11, pad=8)
    ax.spines[['top', 'right']].set_visible(False)
    ax.grid(axis='y', alpha=0.3)

# Single legend for whole figure
heavy_l = plt.Line2D([0], [0], color=COLORS["heavy"], linewidth=4, marker='o',
                     markersize=10, markeredgecolor='black', label="Heavy users (n=5)")
ctrl_l = plt.Line2D([0], [0], color=COLORS["control"], linewidth=4, marker='o',
                    markersize=10, markeredgecolor='black', label="Controls (n=5)")
ind_l = plt.Line2D([0], [0], color="gray", linewidth=1.5, marker='o',
                   markersize=5, alpha=0.6, label="Individual subjects")
fig.legend(handles=[heavy_l, ctrl_l, ind_l], loc="upper center", ncol=3,
           bbox_to_anchor=(0.5, 0.02), fontsize=10, frameon=False)

fig.suptitle("Subject Trajectories: Top 6 ROIs by Effect Size",
             fontsize=14, fontweight='bold', y=1.00)
fig.tight_layout()
fig.savefig(FIG_DIR / "02_trajectories.png", dpi=150, bbox_inches='tight')
plt.close(fig)
print(f"  ✓ {FIG_DIR}/02_trajectories.png")


# ═══════════════════════════════════════════════════════════════════════
# FIGURE 3: Group mean % change with error bars
# ═══════════════════════════════════════════════════════════════════════
print("[viz] Figure 3: Mean percent change comparison...")

# Sort by absolute effect size
plot_df = long_df.reindex(long_df["cohens_d_change"].abs().sort_values(ascending=False).index)

fig, ax = plt.subplots(figsize=(14, 7))
x = np.arange(len(plot_df))
w = 0.38

# Compute SEs from std/sqrt(n)
def get_pct_std(subj_df, roi, group):
    pct_col = f"{roi}_pct_change"
    if pct_col not in subj_df.columns:
        return 0
    return subj_df[subj_df["group"] == group][pct_col].std() / np.sqrt(5)

heavy_se = [get_pct_std(subj_df, r, "heavy") for r in plot_df["roi"]]
ctrl_se = [get_pct_std(subj_df, r, "control") for r in plot_df["roi"]]

ax.bar(x - w/2, plot_df["mean_pct_change_heavy"], w,
       yerr=heavy_se, label="Heavy users", color=COLORS["heavy"],
       alpha=0.75, capsize=3, edgecolor="black", linewidth=0.5)
ax.bar(x + w/2, plot_df["mean_pct_change_control"], w,
       yerr=ctrl_se, label="Controls", color=COLORS["control"],
       alpha=0.75, capsize=3, edgecolor="black", linewidth=0.5)

# Significance markers
for i, (_, row) in enumerate(plot_df.iterrows()):
    if row["p_groups"] < 0.05:
        y = max(row["mean_pct_change_heavy"], row["mean_pct_change_control"]) + 2
        ax.text(x[i], y, "*", ha="center", fontsize=18, color="black", fontweight='bold')

ax.axhline(0, color='black', linewidth=0.8)
ax.set_xticks(x)
ax.set_xticklabels([clean_roi_name(r) for r in plot_df["roi"]], 
                   fontsize=9, rotation=45, ha="right")
ax.set_ylabel("Mean % change (BL → FU)", fontsize=11)
ax.set_title("Cannabis vs Control: Percent Change by ROI (sorted by effect size)\n"
             "* p < 0.05  |  error bars = SEM",
             fontsize=12)
ax.legend(fontsize=11, loc='best')
ax.spines[['top', 'right']].set_visible(False)
ax.grid(axis='y', alpha=0.3)

fig.tight_layout()
fig.savefig(FIG_DIR / "03_pct_change.png", dpi=150, bbox_inches='tight')
plt.close(fig)
print(f"  ✓ {FIG_DIR}/03_pct_change.png")


# ═══════════════════════════════════════════════════════════════════════
# FIGURE 4: Within-subject change distributions (boxplots)
# ═══════════════════════════════════════════════════════════════════════
print("[viz] Figure 4: Change score distributions...")

# Pick top 8 by |d| for boxplot view
top8 = long_df.reindex(long_df["cohens_d_change"].abs().sort_values(ascending=False).index).head(8)

fig, axes = plt.subplots(2, 4, figsize=(16, 8))
axes = axes.flatten()

for ax, (_, row) in zip(axes, top8.iterrows()):
    roi = row["roi"]
    change_col = f"{roi}_change"
    
    if change_col not in subj_df.columns:
        ax.set_visible(False)
        continue
    
    heavy_data = subj_df[subj_df["group"] == "heavy"][change_col].dropna().values
    ctrl_data = subj_df[subj_df["group"] == "control"][change_col].dropna().values
    
    bp = ax.boxplot([heavy_data, ctrl_data], 
                     labels=["Heavy\nusers", "Controls"],
                     widths=0.5, patch_artist=True, showmeans=True,
                     meanprops=dict(marker='D', markerfacecolor='black',
                                   markeredgecolor='black', markersize=6))
    bp['boxes'][0].set_facecolor(COLORS["heavy"])
    bp['boxes'][0].set_alpha(0.6)
    bp['boxes'][1].set_facecolor(COLORS["control"])
    bp['boxes'][1].set_alpha(0.6)
    
    # Overlay individual points
    for x_pos, data, color in [(1, heavy_data, COLORS["heavy"]),
                                (2, ctrl_data, COLORS["control"])]:
        ax.scatter([x_pos] * len(data) + np.random.uniform(-0.05, 0.05, len(data)),
                   data, color=color, edgecolor='black', s=40, zorder=10, alpha=0.9)
    
    ax.axhline(0, color="black", linewidth=0.8, linestyle='--', alpha=0.5)
    
    is_volume = roi in SUBCORTICAL_ROIS
    unit = "mm³" if is_volume else "mm"
    ax.set_ylabel(f"Change ({unit})", fontsize=9)
    ax.set_title(f"{clean_roi_name(roi)}\nd={row['cohens_d_change']:.2f}, p={row['p_groups']:.3f}",
                 fontsize=10)
    ax.spines[['top', 'right']].set_visible(False)
    ax.grid(axis='y', alpha=0.3)

fig.suptitle("Distribution of Change Scores: Top 8 ROIs by Effect Size",
             fontsize=14, fontweight='bold', y=1.00)
fig.tight_layout()
fig.savefig(FIG_DIR / "04_boxplots.png", dpi=150, bbox_inches='tight')
plt.close(fig)
print(f"  ✓ {FIG_DIR}/04_boxplots.png")


# ═══════════════════════════════════════════════════════════════════════
# FIGURE 5: Summary table
# ═══════════════════════════════════════════════════════════════════════
print("[viz] Figure 5: Summary table...")

# Sort by absolute d
summary = long_df.copy()
summary["abs_d"] = summary["cohens_d_change"].abs()
summary = summary.sort_values("abs_d", ascending=False)

fig, ax = plt.subplots(figsize=(14, 8))
ax.axis('off')

# Build table data
header = ["ROI", "Heavy Δ%", "Control Δ%", "Cohen's d", "p (groups)", "Sig?"]
rows = []
for _, r in summary.iterrows():
    sig = "★ p<0.05" if r["p_groups"] < 0.05 else ("○ p<0.10" if r["p_groups"] < 0.10 else "")
    rows.append([
        clean_roi_name(r["roi"]),
        f"{r['mean_pct_change_heavy']:+.2f}%",
        f"{r['mean_pct_change_control']:+.2f}%",
        f"{r['cohens_d_change']:+.2f}",
        f"{r['p_groups']:.3f}",
        sig,
    ])

table = ax.table(cellText=rows, colLabels=header, loc="center",
                 cellLoc="center", colWidths=[0.3, 0.13, 0.13, 0.12, 0.12, 0.15])
table.auto_set_font_size(False)
table.set_fontsize(10)
table.scale(1, 1.7)

# Style header
for i in range(len(header)):
    table[(0, i)].set_facecolor("#34495E")
    table[(0, i)].set_text_props(color="white", weight="bold")

# Color rows by effect size magnitude
for i, (_, r) in enumerate(summary.iterrows(), start=1):
    abs_d = abs(r["cohens_d_change"])
    if abs_d >= 0.8:
        color = "#FADBD8"  # light red - large effect
    elif abs_d >= 0.5:
        color = "#FCF3CF"  # light yellow - medium effect
    else:
        color = "#FFFFFF"  # white - small/no effect
    for j in range(len(header)):
        table[(i, j)].set_facecolor(color)
    
    # Highlight significant ones
    if r["p_groups"] < 0.05:
        for j in range(len(header)):
            table[(i, j)].set_text_props(weight="bold")

ax.set_title("Cannabis vs Controls: Longitudinal Brain Change Summary\n"
             "(n=5 per group, sorted by |Cohen's d|)",
             fontsize=13, fontweight='bold', pad=20)

# Legend for color coding
legend_text = (
    "Color coding:  "
    "■ |d| ≥ 0.8 (large effect)   "
    "■ |d| ≥ 0.5 (medium effect)   "
    "□ |d| < 0.5 (small effect)\n"
    "★ = p < 0.05 (uncorrected)   ○ = p < 0.10 (trend)"
)
fig.text(0.5, 0.05, legend_text, ha="center", fontsize=9, style='italic')

fig.tight_layout()
fig.savefig(FIG_DIR / "05_summary_table.png", dpi=150, bbox_inches='tight')
plt.close(fig)
print(f"  ✓ {FIG_DIR}/05_summary_table.png")


# ═══════════════════════════════════════════════════════════════════════
# Final summary
# ═══════════════════════════════════════════════════════════════════════
print()
print("=" * 70)
print(" Visualization Summary")
print("=" * 70)
print()
print(f"All figures saved to: {FIG_DIR}/")
print()
print("Files created:")
print("  01_forest_plot.png      - Effect sizes for all 20 ROIs")
print("  02_trajectories.png     - BL→FU lines per subject (top 6 ROIs)")
print("  03_pct_change.png       - Mean % change bar chart with SEM")
print("  04_boxplots.png         - Change distributions with raw points")
print("  05_summary_table.png    - Full results table")
print()
print(f"Key findings (from {ANA_DIR.name}):")
sig = long_df[long_df["p_groups"] < 0.05]
if len(sig) > 0:
    print(f"  Significant (p<0.05): {len(sig)} ROIs")
    for _, r in sig.iterrows():
        print(f"    {r['roi']}: d={r['cohens_d_change']:+.2f}, p={r['p_groups']:.3f}")

large = long_df[long_df["cohens_d_change"].abs() >= 0.8]
print(f"\n  Large effects (|d|>0.8): {len(large)} ROIs")
for _, r in large.sort_values("cohens_d_change", key=abs, ascending=False).iterrows():
    print(f"    {r['roi']}: d={r['cohens_d_change']:+.2f}, p={r['p_groups']:.3f}")
