# ECE327 Project - Microsoft BrainWave MVM Engine



# Architecture Breakdown

![Diagram of Microsoft BrainWave MVM implemented in the lab](/img_assets/mvm_engine_breakdown.png)
*Diagram adapted from course materials prepared by Professor Andrew Boutros of the Electrical and Computer Engineering Department, University of Waterloo*

A shared input vector is broadcast across parallel output lanes, each containing matrix memory, an 8-element dot-product unit, and an accumulator for computing one output-vector element.


# Project Overview

This project came from a digital hardware course I took during the S26 term at the University of Waterloo (ECE 327 - Digital Hardware Systems). For the final lab project, we were tasked with implementing a highly-optimized matrix-vector multiplication (MVM) engine based on Microsoft's 2018 BrainWave project. The final design achieved 53.81 GOPS throughput at 299 MHz through pipelining and parallel output lanes on an AMD Xilinx FPGA.


A shared input vector is broadcast across parallel output lanes, each containing matrix memory, an 8-element dot-product unit, and an accumulator for computing one output-vector element.



# Takeaways 
Being written in SystemVerilog, it gave me a lot more appreciation for the low-level design that surrounds ML/DL services that are used on a daily basis. It was a challenging project but I enjoyed seeing how all the different hardware components could be orchestrated to build a fundamental component to modern day AI/Deep Learning infrastructure. 


# Credits

Big thanks to our professor Andrew Boutros for authoring this lab project, and providing us with the necessary hardware in the lab workstations to test our design. 


