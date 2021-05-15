.PHONY: data clean plot all

all: plot

plot: exercise_1_1.pdf exercise_1_3.pdf

two_%_i32s:
	futhark dataset -b --i32-bounds=-10000:10000 
	                -g [$*]i32 -g [$*]bool > $@

exercise_1_1.pdf: benchmark
	python plot.py exercise_1_1 $(SIZES)

exercise_1_3.pdf: benchmark
	python plot.py exercise_1_3 $(SIZES)

benchmark: exercise_1_1-opencl.json exercise_1_1-c.json exercise_1_3-opencl.json exercise_1_3-c.json exercise_2_3-c.json exercise_2_3-opencl.json

SIZES = 100 1000 10000 100000 1000000 5000000 10000000

exercise_1_1-opencl.json: $(SIZES:%=two_%_i32s) exercise_1_1.fut
	futhark bench --backend=opencl \
	              --json exercise_1_1-opencl.json \
	              exercise_1_1.fut

exercise_1_1-c.json: $(SIZES:%=two_%_i32s) exercise_1_1.fut
	futhark bench --backend=c \
	              --json exercise_1_1-c.json \
	              exercise_1_1.fut

exercise_1_3-opencl.json: $(SIZES:%=two_%_i32s) exercise_1_3.fut
	futhark bench --backend=opencl exercise_1_3.fut --json exercise_1_3-opencl.json

exercise_1_3-c.json: $(SIZES:%=two_%_i32s) exercise_1_3.fut
	futhark bench --backend=c exercise_1_3.fut --json exercise_1_3-c.json

exercise_2_3-c.json: $(SIZES:%=two_%_i32s) exercise_2_3.fut
	futhark bench --backend=c exercise_2_3.fut --json exercise_2_3-c.json

exercise_2_3-opencl.json: $(SIZES:%=two_%_i32s) exercise_2_3.fut
	futhark bench --backend=c exercise_2_3.fut --json exercise_2_3-opencl.json

clean:
	rm -f two_*_i32s *.json *.pdf *.bin *.c *i32s *i64s



SIZES2 = 100 1000 10000 100000 1000000 10000000
SIZES23 = 100 1000 10000 100000 1000000
plot_2_2: exercise_2_2.pdf exercise_2_2_2.pdf exercise_2_3.pdf

sr_%_i32s:
	futhark dataset -b -g [$*]i32 -g [$*]bool > $@

i_%_i64s:
	futhark dataset -b --i64-bounds=0:9999 -g [$*]i64 -g [$*]i64 > $@

exercise_2_2.pdf: benchmark_2
	python plot2.py exercise_2_2 $(SIZES2)

exercise_2_2_2.pdf: benchmark_2
	python plot2.py exercise_2_2_2 $(SIZES2)

exercise_2_3.pdf: benchmark_2
	python plot23.py exercise_2_3 $(SIZES23)
# exercise_2_2_default.pdf: benchmark_2
# 	python plot2.py exercise_2_2_default $(SIZES)

benchmark_2: exercise_2_2.json exercise_2_2_default.json exercise_2_2_2.json exercise_2_2_2_default.json exercise_2_3.json exercise_2_3_default.json 

exercise_2_2.json: $(SIZES2:%=sr_%_i32s) exercise_2_2.fut
	futhark bench --backend=opencl \
	              --json exercise_2_2.json \
	              exercise_2_2.fut

exercise_2_2_default.json: $(SIZES2:%=sr_%_i32s) exercise_2_2_default.fut
	futhark bench --backend=opencl \
	              --json exercise_2_2_default.json \
	              exercise_2_2_default.fut

exercise_2_2_2.json: $(SIZES2:%=sr_%_i32s) exercise_2_2_2.fut
	futhark bench --backend=opencl \
	              --json exercise_2_2_2.json \
	              exercise_2_2_2.fut

exercise_2_2_2_default.json: $(SIZES2:%=sr_%_i32s) exercise_2_2_2_default.fut
	futhark bench --backend=opencl \
	              --json exercise_2_2_2_default.json \
	              exercise_2_2_2_default.fut

exercise_2_3.json: $(SIZES23:%=i_%_i64s) exercise_2_3.fut
	futhark bench --backend=c \
	              --json exercise_2_3.json \
	              exercise_2_3.fut

exercise_2_3_default.json: $(SIZES23:%=i_%_i64s) exercise_2_3_default.fut
	futhark bench --backend=c \
	              --json exercise_2_3_default.json \
	              exercise_2_3_default.fut
