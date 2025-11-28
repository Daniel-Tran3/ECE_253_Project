# ECE_284_Project

For ECE 284.

Alphas:

Alpha 1: Clock gating to turn off blocks unused in each phase of operation.

Alpha 2: Corelet to facilitate output channel tiling (16 output channels tiled into 8). 
Configurable between 2-bit and 4-bit activations.

Alpha 3: Configurable activation function.
Options are ReLU and LeakyReLU, where the negative scaling must be a value from [0, 0.5, 0.25, 0.125].
Scaling implemented by arithmetic right-shift.

Alpha 4: 16 x 16 parameterizable version + verification for 16 x 16 array. (No tiling, all operations done in one "round").

Alpha 5: Northern IFIFO to feed PSUMs back into MAC array for row tiling.

Alpha 6: Thorough verification for multiple different edge-case layers.
Layers generated artificially based on hypothetical edge-case weights and activations.
Designed to stress-test implementation for maximum positive and maximum negative values.
