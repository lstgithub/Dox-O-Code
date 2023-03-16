# Dox-O-Code

This is an advanced PowerShell script for building custom *documentation-as-a-code* approach in CI environment. It uses Pandoc and MiKTeX to produce PDF files from the properly prepared MD source files.

# Features
- Supports embedding and reusage of multiple source files (e.g., Doc1 and Doc2 has some common parts. In this case, these parts Doc3 and Doc4 can be embedded automatically into "parent" documents, to reduce maintenance time);
- Supports the same approach for shared illustrations inside of documents;
- Fully automated and maintenance-free;
- Usage of open-source Pandoc and MiKTeX tools;
- CI oriented (Git and Jenkins compatible);
- Highly customizable;
- Supports exception handling;
- Supports webhook notifications.

# Requirements
- Jenkins node with Windows OS;
- https://pandoc.org/ and https://miktex.org/;
- Git repository with Markdown source files. Desired structure is:
    '''
    Root
        SharedImages folder
            Image1.png
        SomeDocuments folder
            Doc1.md
            Image1Doc1.png
        SomeOtherDocuments folder
            Doc2.md
            Image2Doc2.png
        Reusable_Text_Part.md file
        Reusable_Text_Another_Part.md file
    '''

# Desired flow example
A user is working with MD document from the repository. After finish, he commits changes. This starts a triggered call of this script on the remote Jenkins node to produce a customized PDF file for further usage.

# Script usage
Just create a Jenkins job with a call of this script and some required variables to be used inside (if required).

# Images reusage
Here is a hardcoded folder name - **SharedImages**, and images that are used across documents should be placed here. Script will identify this condition while iterating through each document and image path will contain that folder's name.

# Docs reusage
Script iterates each document and if it finds a pattern *~SomeReusableText~* and there is a *SomeReusableText.md* document in the repository's root folder, autoreplacement will be done to produce a complete PDF document.