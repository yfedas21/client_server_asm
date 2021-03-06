v1, rev1

In this tutorial, I will show potential users how to add this project to Visual Studio to debug/compile it. 

1. Open Visual Studio, choose New Project, select Visual C++, and choose Empty Project. 
2. After naming the project, a blank project directory will open. Right-click on Source Files -> Add -> New Item... -> <Leave C++ File (.cpp) selected and type "main.asm" as 	the Name of the file, and click Add. 
3. Once the main.asm file is in the project directory, copy the main.asm file contents from my project directory (from either Github or the shared drive) and paste it in the 	main.asm file in your project.
4. At this point, you need to tell Visual Studio that it is a MASM project (the project will build as is, but when you try to run it, VS can't find an executable file). 	Right-click your project name in the Solution Explorer, hover over Build Dependencies, and select Build Customizations... From the list in the Visual C++ Build 	Customization Files popup box, choose masm(targets, .props). Click OK. 
5. Right-click on main.asm (or whatever you named your source file) and choose Properties. You should see a pop up box titled <source file name here> Property Pages, so in my 	case, I see main.asm Property Pages. In the left pane, Expand Configuration Properties, choose General, and set the option Excluded From Build as No. Following a 	similar procedure, set the Item Type to Microsoft Macro Assembler. Choose OK to close the window.
6. The next step is to tell VS where the Irvine32.inc file is. Open the project properties window (right click on the project name in Solution Explorer and choose Properties), 	select VC++ Directories in the Configuration Properties pane on the left to add an entry in Include Directories. Click on Include Directories, choose <Edit...>, and in 	the top text box, click on the Add Folder button (little yellow folder with star icon). Click on the ... button to browse, and browse to and select the folder that 	contains my custom Irvine32.inc and Irvine32.lib (it will be in my project directory, either on Github or on the shared drive). Select OK in the Include Directories 	window. Go down two options and and an entry in the Library Directories (if the Irvine32.inc and .lib are in the same directory, this entry will be the same as the one 	you just did). Don't close the Properties window yet. 
7. Now, we need to specify the entry point. To do this, expand Linker in the Configuration Properties, and click on Advanced. In the Entry Point textbox, enter "main" (without 	quotes). Click OK to close the project properties. 
8. The project will (should) successfully build and generate an executable. At this point, you can run the debugger as well. 




A FEW NOTES:

Inside the project directory, you will find a file called server_asm.asm. This file was auto-generated by the compiler. Basically, I followed a tutorial on Microsoft documentation on how to create this project in C++, then built and set the correct options to generate an assembly file. That is what server_asm.asm is. The only way I used this file was to see what the syntax is for including libraries in assembler (i.e. INCLUDELIB <lib name without .lib at the end>) and for debugging purposes. 

Here are the steps to generate an assembly file for a C++ project in VS 2017:
(SOURCE https://stackoverflow.com/questions/1020498/how-to-view-the-assembly-behind-the-code-using-visual-c)


MODIFIED December 8, 2018
BY Yuriy Fedas
