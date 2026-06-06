set term pngcairo size 2560,1440
stats 'imbalance.gpd' using 1 nooutput
XMAX = STATS_max
set style fill solid
set palette viridis
set xtics 0.1
set xlabel "Imbalance"
set ylabel "Count"
set title "Histogram of contest imbalances"
plot 'imbalance.gpd' using ($1+0.05):2:1 with boxes fc palette title "Codeforces contests"
