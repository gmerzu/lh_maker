lh_maker
========

Script to add/remove/modify license headers on project files.

### Usage overview ###

+ To add headers:  
`make_lh.pl --interactive --color --arg ver=1.0 -- path_to_the_project`
+ To remove headers:  
`make_lh.pl --remove -- path_to_the_project`
+ To modify headers:  
`make_lh.pl --replace --preservevar=DATE --preservearg=var -- path_to_the_project`

### Full option list ###

    USE: make_lh.pl [options] [dir|file]...  
      options:  
       -h|--help               this help  
       -c|--color              make output in color  
       -i|--interactive        work interactively  
       -I|--noninteractive     work non-interactively (default)  
       -f|--force              force add header when it seems to be present  
       -r|--remove             remove headers from the files  
       -R|--onlyremove         remove headers without adding new ones  
       -m|--replace            replace headers  
       -w|--reset              ask for all fields if needed  
       -t|--template=<file>    use this template for all files  
       -n|--newtemplate=<file> use this template for replaced headers  
       -v|--vars=<file>        use this template for templates vars  
       -e|--ext=<extension>    treat all files as they have this extension  
       -p|--preserveall        preserve everything (implies -pva && -paa)  
       -pv|--preservevar=<var> preserve this variables from templates, can be passed multiple times  
       -pva|--preserveallvar   preserve all template variables  
       -pa|--preservearg=<arg> preserve this args from templates, can be passed multiple times  
       -paa|--preserveallarg   preserve all template arguments  
       -a|--arg=<name=value>   replace the name with the value in templates if present,
                               parameter can't be passed multiple times

### Configuration ###

Copy *config_dir* from the repo as *~/.lh_maker*.

* *~/.lh_maker/rc*        --  main config file
* *~/.lh_maker/vars*      --  variables passed to templates
* *~/.lh_maker/template*  --  dir containing files for templates

#### Main config file ####

Main config file is *~/.lh_maker/rc*. It consists of script options and declarations of templates.

Example options configuration:
- `$color = 1`
- `$interactive = 1`
- `$vars = ~/.lh_maker/vars`

Example declarations of templates:
- `cpp = cpp cc c h`
- `@cpp = @cpp`
- `perl = pl`
- `@shell = @perl sh csh`

Format is next:  
_template_name|@template_group = [extension|@template_name|@template_group]..._

#### Variables file ####

Located by **$vars** variable in the main config, or by **--vars** option passed to the script.  
It consist of lines *key = value*. *Values* can contain shell commands.

Example:
- `AUTHOR_NAME = Me`
- `AUTHOR_EMAIL = my@mail.com`
- `DATE = $(env LANG=C date +"%B %d, %Y")`

#### Template file ####

Templates are located in the *~/.lh_maker/templates* directory.
- Can contain script defined variables, such as file name, e.g. *@$FILE_SHORT@*.
- Can contain variables from the **$vars** file, e.g. *@AUTHOR_NAME@*, *@DATE@*.
- Can contain arguments passed to the script via **--arg** options, e.g. *@$ARG[ver]@*.
- Can contain instructions to ask a user for a variable, e.g. *@$ASK[brief]@*.

Example:

    // @file     @$FILE_SHORT@  
    // @brief    @$ASK[brief]@  
    // @author   @AUTHOR_NAME@ (@AUTHOR_EMAIL@)  
    // @version  @$ARG[ver]@  
    // @date     Created @DATE@

