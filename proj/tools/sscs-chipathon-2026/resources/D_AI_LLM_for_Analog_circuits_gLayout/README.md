# gLayout Track Resources

- [Brief Overview of the gLayout](./files/Glayout_Overview.pdf)
- 🤖 [GitHub Repo](https://github.com/ReaLLMASIC/gLayout)
- [Project template](https://github.com/LuighiV/iic-osic-tools-project-template/tree/main)
- :books: [gLayout Tutorials](https://github.com/ReaLLMASIC/gLayout/tree/main/tutorial)
  - [Flipped Voltage Follower (FVF)](https://github.com/ReaLLMASIC/gLayout/blob/main/tutorial/glayout_tutorial_FVF_part1.ipynb)
  - [Operational Transconductance Amplifier (OTA)]()
- 🦾 [Contribution Guidelines](https://github.com/ReaLLMASIC/gLayout/blob/main/docs/contributor_guide.md)


## Environment setup

There are multiple references on how to have the environment up and running.
For gLayout standalone you can use the repository reference from here [gLayout_Install](https://github.com/ReaLLMASIC/gLayout/blob/main/docs/gLayout_Install.md).

However, for this chipathon edition we are proposing using a [Project template](https://github.com/LuighiV/iic-osic-tools-project-template/tree/main) that has 
configurations predefined and might help ramp-up process. Also, as we have worked
closed with Prof. Harald (creator of iic-osic-tools docker image), extra steps
like klive installation on Klayout are not longer required as this plugin is 
included from beginning.

Please, check the following videos we have prepared for it that explains the
process.

- :clapper: [Environment setup, Part 1](https://drive.google.com/file/d/19uoJES17iSrIZ7gf-XgP9TaF4Km1wNkQ/view?usp=drive_link): Introduction to environment 
- :clapper: [Environment setup, Part 2](https://drive.google.com/file/d/100nhUwkqkQ4u5Csk399gOO5OgnYPentf/view?usp=drive_link): Demo 
- :clapper: [Environment setup, Part 3](https://drive.google.com/file/d/1KhfwmIuLM5FjjnFnWFwCYfxd0WJdO2WD/view?usp=drive_link): Q&A

The slides used alongside the videos are here:

- :bar_chart: [Environment_setup](https://docs.google.com/presentation/d/e/2PACX-1vT8XybzYWQqSTboEH1udOfj2LSpn-lkMgQHm4f-wMGISH3S9KbROQs2LmMsBGW6Y194ylUcF9_wdXbx/pub)

## gLayout

### A PDK-agnostic layout automation framework for analog circuit design.

gLayout is a powerful layout automation tool that generates DRC-clean circuit layouts for any technology implementing the gLayout framework. It is implemented as an easy-to-install Python package with all dependencies available on PyPI.

Key features:

- PDK-agnostic layout generation
  - Generic layer mapping
  - Technology-independent design rules
  - Support for multiple PDKs (sky130, gf180)
  - DRC-clean layout generation
- Basic Cell Generators
  - Via stack generation
  - Transistor generation (NMOS/PMOS)
  - Guard ring generation
  - And more...
- Natural language processing for circuit design
  - Convert natural language descriptions to layouts
  - Support for standard components
  - Custom component definitions
- Integration with Klayout for visualization and verification

## gLayout introduction

Please, check the following videos regarding the gLayout framework and the
tutorial to create a cell from scratch (FVF tutorial)

- :clapper: [gLayout_introduction, Part 1](https://drive.google.com/file/d/1sJSCSv0T7r9nka_SQAZxToDHD5SLjenr/view?usp=sharing): Introduction to gLayout Framework
- :clapper: [gLayout_introduction, Part 2](https://drive.google.com/file/d/1mE7ArqKS4Zq414yuNh8bLSt22_SCRQk4/view?usp=sharing): Basic example - current mirror
- :clapper: [gLayout_introduction, Part 3](https://drive.google.com/file/d/1QXKJUZVjU50XMGrF6MBC5AbXlHe_aoEV/view?usp=sharing): Basic example - FVF generator
- :clapper: [gLayout_introduction, Part 4](https://drive.google.com/file/d/13LRK12KrqT6uyCcQC6O7biZ2cl6yVD69/view?usp=sharing): FVF tutorial, creating a cell from scratch


The slides used alongside the videos are here:

- :bar_chart: [gLayout_introduction](https://docs.google.com/presentation/d/e/2PACX-1vShUolgExqu0rq-M0L9Y4uuYnWmuTPAg7R7E6Y9oLlg0vCBAyGUQjGL6kjTHvRW36nkzrMMOOOFz7_k/pub)

## Citation

If you use gLayout in your research, please cite our papers:

```bibtex
@article{hammoud2024human,
  title={Human Language to Analog Layout Using gLayout Layout Automation Framework},
  author={Hammoud, A. and Goyal, C. and Pathen, S. and Dai, A. and Li, A. and Kielian, G. and Saligane, M.},
  journal={Accepted at MLCAD},
  year={2024}
}

@article{hammoud2024reinforcement,
  title={Reinforcement Learning-Enhanced Cloud-Based Open Source Analog Circuit Generator for Standard and Cryogenic Temperatures in 130-nm and 180-nm OpenPDKs},
  author={Hammoud, A. and Li, A. and Tripathi, A. and Tian, W. and Khandeparkar, H. and Wans, R. and Kielian, G. and Murmann, B. and Sylvester, D. and Saligane, M.},
  journal={Accepted at ICCAD},
  year={2024}
}
```
