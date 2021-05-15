#!/usr/bin/env python

import json
import sys
import numpy as np

import matplotlib

matplotlib.use('Agg') # For headless use

import matplotlib.pyplot as plt

benchmark = sys.argv[1]
data_sizes = list(map(int, sys.argv[2:]))

opencl_filename = '{}_default.json'.format(benchmark)
c_filename = '{}.json'.format(benchmark)

opencl_json = json.load(open(opencl_filename))
c_json = json.load(open(c_filename))

opencl_measurements = opencl_json['{}_default.fut'.format(benchmark)]['datasets']
c_measurements = c_json['{}.fut'.format(benchmark)]['datasets']

opencl_runtimes = [ np.mean(opencl_measurements['i_{}_i64s'.format(n)]['runtimes']) / 1000
                    for n in data_sizes ]
c_runtimes = [ np.mean(c_measurements['i_{}_i64s'.format(n)]['runtimes']) / 1000
               for n in data_sizes ]
speedups = list(map(lambda x, y: x / y, c_runtimes, opencl_runtimes))

fig, ax1 = plt.subplots()
if benchmark == 'exercise_2_2':
    opencl_runtime_plot = ax1.plot(data_sizes, opencl_runtimes, 'b-', label='Scan runtime')
    c_runtime_plot = ax1.plot(data_sizes, c_runtimes, 'g-', label='Segscan runtime')
elif benchmark == 'exercise_2_2_2':
    opencl_runtime_plot = ax1.plot(data_sizes, opencl_runtimes, 'b-', label='Reduce runtime')
    c_runtime_plot = ax1.plot(data_sizes, c_runtimes, 'g-', label='Segreduce runtime')
else:
    opencl_runtime_plot = ax1.plot(data_sizes, opencl_runtimes, 'b-', label='Default reduce_by_index runtime')
    c_runtime_plot = ax1.plot(data_sizes, c_runtimes, 'g-', label='Our reduce_by_index runtime')
ax1.set_xlabel('Input size')
ax1.set_ylabel('Runtime (ms)', color='k')
ax1.tick_params('y', colors='k')
plt.xticks(data_sizes, rotation='vertical')
ax1.semilogx()
ax2 = ax1.twinx()
if benchmark == 'exercise_2_2':
    speedup_plot = ax2.plot(data_sizes, speedups, 'k-', label='Scan speedup')
elif benchmark == 'exercise_2_2_2':
    speedup_plot = ax2.plot(data_sizes, speedups, 'k-', label='Reduce speedup')
else:
    speedup_plot = ax2.plot(data_sizes, speedups, 'k-', label='reduce_by_index speedup')
ax2.set_ylabel('Speedup', color='k')
ax2.tick_params('y', colors='k')

plots = opencl_runtime_plot + c_runtime_plot + speedup_plot
labels = [p.get_label() for p in plots]
ax1.legend(plots, labels, loc=0)

fig.tight_layout()
plt.show()

plt.rc('text')
plt.savefig('{}.png'.format(benchmark), bbox_inches='tight')
