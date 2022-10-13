# Code for Dynamic Pricing for Non-fungible Resources
This repository contains the code used to generate the figures in the paper
[Dynamic Pricing for Non-fungible Resources](https://arxiv.org/abs/2208.07919).

## Running the script
Clone the repository, navigate to the folder in your terminal, and (assuming Julia is installed), simply run

```bash
julia sims.jl
```

The script will activate the environment specified by `Project.toml`, 
install all required packages, and then run the program.
Figures are output to the `figs/` folder.

## Changing parameters
The parameters are set to those used in the paper. These can be changed in the `sims.jl` file.