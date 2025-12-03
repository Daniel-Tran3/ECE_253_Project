# ECE_284_Project

For ECE 284.

Input File Formats, for easier readability.

Part 1: See miscellaneous/python_files/ProjectP1.ipynb for an example of how to generate these files.
Each line of each weight .txt file should have the rows for one column, in reverse order, on each line, as below:
col0row7[msb-lsb],col0row6[msb-lst],....,col0row0[msb-lst]
col1row7[msb-lsb],col1row6[msb-lst],....,col1row0[msb-lst]

Each line of activation .txt should have the columns for one time step, in reverse order, on each line.
time0row7[msb-lsb],time0row6[msb-lst],....,time0row0[msb-lst]

Similar to activation.txt for psum.txt files and out.txt file.

Part 2: See miscellaneous/python_files/ProjectP2.ipynb for an example of how to generate the 2-bit files.
For each column tile, create a file named Tile[tile_id] and store the unique weights, psums, and outputs for that tile.
Activation.txt is stored outside of both Tile/ directories.

Each two lines of each weight .txt file should have the rows for one column, in reverse order, on each line.
They should be interspersed as follows:
col0row14[msb-lsb],col0row12[msb-lst],....,col0row0[msb-lst]
col0row15[msb-lsb],col0row13[msb-lst],....,col0row1[msb-lst]

Each line of activation .txt should have the columns for one time step, in reverse order, on each line.
time0row7[msb-lsb],time0row6[msb-lst],....,time0row0[msb-lst]

Similar to activation.txt for psum.txt files and out.txt file.
The 2-bit files created above are stored in one P2_Files directory in Part-2.
The 4-bit files, which should be created in the same way, but without interspersing the weights.
The 4-bit files should also be stored in the Tile0 and Tile1 directories, with activation.txt outside of them.
All of this should be contained in one P1_Files directory in Part-1.

Part 3: Create a directory called OSWS_Files in the root directory. Provide output.txt, activation.txt, and weights_*.txt as in part 1, except that the weights should be transposed; thus, each line should contain the weights for PE columns 7-0, i.e. they should contain the weights corresponding to channels 7-0, for each input channel from 0-7. 

In order for output-stationary computation to work, there must exist an activation_os.txt file that contains the activations in a specific pattern. For each input channel from 0-7 within the (only) tile, each of these lines must be appended to the activation_os.txt file:

Nij0…nij3 nij6…nij9
Nij1…nij4 nij7…nij10
Nij2…nij5 nij8…nij11
Nij6…nij9 nij12…nij15
Nij7…nij10 nij13…nij16
Nij8…nij11 nij14…nij17
Nij12…nij15 nij18…nij21
Nij13…nij16 nij19…nij22
Nij14…nij17 nij20…nij23

Note: For Part 3 and all other derivative alphas, we test on nij 0-15 for both WS and OS. 
However, our OS hardware only calculates up to nij 0-7 and zeros out the other columns.
The OS verification is always the last one run, and therefore expects to see outputs 8-15 error.
This is expected, and does not (we feel) impact the correctness of the design.
Outputs 0-7 are the ones we actually calculate, and those should be correct.
Outputs 8-15 are also correct for any WS calculations.


Alphas:

Alpha 1: Clock gating to turn off blocks unused in each phase of operation. 
As the inputs are the same as Part-1, simply copy that input file structure.

Alpha 2: Dual corelet instantiation to facilitate output channel tiling (16 output channels tiled into 8). 
Configurable between 2-bit and 4-bit activations. 
As the inputs are the same as Part-2, simply copy that input file structure.

Alpha 3: Configurable activation function.
Options are ReLU and LeakyReLU, where the negative scaling must be a value from [0, 0.5, 0.25, 0.125].
Scaling implemented by arithmetic right-shift.
Generate output by replacing ReLU with a clipped output (floored to closest lower integer). 
See miscellaneous/python_files/ProjectResNet.ipynb for an example of how to generate the output files in this way.
Otherwise, follow Part-1's input file generation.

Alpha 4: 16 x 16 parameterizable version + verification for 16 x 16 array. (No tiling, all operations done in one "round").
Generation of output files demonstrated in miscellaneous/python_files/ProjectFileGen16x16.ipynb
Simply insert what row and column values you would like, and make sure to alter the parameters in core_tb.v and the row_num
and col_num variables in the Datahub calculations to ensure that no tiling takes place.
Otherwise, follow Part-1's input file structure.


Alpha 5: Northern IFIFO to feed PSUMs back into MAC array for row tiling.
The core can be programmed to perform input channel tiling 
In weight-stationary, it retrieves partial sums computed for previous input channel tiles and feeding them back into the corelet to be accumulated on. In output stationary, it simply fetches weights/activations for all input tiles into SRAM and streams them out such that each tile performs MACs on all weight*activation pairings relevant for that particular tile’s assigned (nij, out_channel) pairing.

There must exist a P16x8_Files directory in the root directory. Within it are all the weights, activations, and ground truths.

There must exist two directories in P16x8_Files: Tile0, and Tile1. Within each Tile* directory, each respective files’ weight.txt and activation.txt must exist; their formats should match those used in Part 1. Within the base P16x8_Files directory (outside Tile0/Tile1), there should exist an out_no_relu.txt and an out_relu.txt file, which contain the un-activated partial sums and the post-activation (ReLU) partial sums respectively, in the same format for out.txt as in the original Part 3. Additionally, the P16x8_Files directory must include an activation_os.txt directory. It should be the activations of Tile0 and Tile1, converted to the output-stationary format described in Part 3 and concatenated together (Tile0 appears in the first lines, then Tile 1). 


Alpha 6: The core performs weight-stationary accumulation in-place for each pair of (output channel, nij) by performing the nij’ offset computation from nij to determine the appropriate sequence of accesses needed from the set of activations. This is implemented as a part of Part 3, so please perform testing in the Part 3 folder and use Part 3 instructions.



Alpha 7: Thorough verification for multiple different edge-case layers.
Layers generated artificially based on hypothetical edge-case weights and activations.
Designed to stress-test implementation for maximum positive and maximum negative values.

Vanilla and NIJ follow Part-1 input file structure.
(Generation is more or less the same, but nij values of the layer should match the parameter in the core_tb).
2bit follows Part-2's input file structure and generation.
16x16 follows Alpha 4's input file structure and generation.

data_ directories contain sample inputs that must be copied properly to their respective verif_ directories.
Iveri and irun are run from the verif_ directories. Please check the data_ directories and refer to previous guidelines for
how to copy those data files for thorough verification.

