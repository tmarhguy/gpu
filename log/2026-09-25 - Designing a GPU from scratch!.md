2026-09-25 - Designing a GPU from scratch!

It's been a really tiring week. Interviews, exams, quizzes, internship applications! The one way to wind down is to pursue the fun parts that make all the grind worth it: building a gpu from scratch.

After designing [Tomato](https://tomato.tmarhguy.com) from scratch, I have touched on all the primitive areas that matter: physics, microarchitecture, rtl/gates, ISA, OS, assembly, app development and end to end design that works! I however was intentionally "soft" on the video engine. Infact, in one iteration, I resolved to using a trual dual port together with a polling device to render an 80 x 60 display window frame.

This project, hence, is a chance to dive very deep into what the buzz word, graphics processing unit means. How to build one, and learn from the design choices that can be made. Who knows, I may make it as assessible as tomato, so much that you can follow and build your own discrete gpu in your house!

It is almost ridiculous that I keep taking on these hard, end-to-end challenges, but it is becoming increasingly intentional. As AI becomes more capable and increasingly embedded in development, it also becomes easier to build systems whose underlying mechanisms you never truly had to understand. I have a deep awe for AI, and I am excited to eventually work in ASIC and related fields alongside these tools, but I do not want that capability to come at the expense of understanding the machine beneath them. At least once, I want to know that I can reason through the layers myself.