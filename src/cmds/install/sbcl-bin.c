#include <stdio.h>
#include <stdlib.h>
#include "util.h"
#include "ros_install.h"
#include "opt.h"

char* arch_(struct install_options* param) {
  return cat(param->arch,"-",param->os,NULL);
}

char* sbcl_bin(char* file);

int sbcl_version_bin(struct install_options* param)
{
  char* home= homedir();
  char* ret;
  char* platforms_html=cat(home,"tmp",SLASH,"sbcl-bin.html",NULL);
  ensure_directories_exist(platforms_html);

  if(!param->version) {
    printf("version not specified\nto specify version,downloading platform-table.html...");
    download_simple("http://www.sbcl.org/platform-table.html",platforms_html,0);
    printf("done\n");
    param->version=sbcl_bin(platforms_html);
    printf("version to install would be '%s'\n",param->version);
  }else {
    param->version=q(param->version);
  }
  param->arch_in_archive_name=1;
  param->expand_path=cat(home,"src",SLASH,param->impl,"-",param->version,"-",arch_(param),SLASH,NULL);
  s(platforms_html),s(home);
  return 1;
}

char* sbcl_bin_extention(struct install_options* param)
{
#ifdef _WIN32
  return "msi";
#else
  return "tar.bz2";
#endif
}

char* sbcl_uri_bin(struct install_options* param)
{
  /*should I care about it's existance? */
  char* arch=arch_(param);
  char* ret=cat("http://prdownloads.sourceforge.net/sbcl/sbcl-",param->version,
                "-",arch,
                "-binary.",
                sbcl_bin_extention(param)
                ,NULL);
  s(arch);
  return ret;
}

#ifdef _WIN32
int sbcl_bin_expand(struct install_options* param)
{
  char* impl=param->impl;
  char* version=q(param->version);
  int ret;
  char* home= homedir();
  char* arch= arch_(param);
  char* archive=cat(impl,"-",version,"-",arch,".msi",NULL);
  char* log_path=cat(home,"impls",SLASH,"log",SLASH,impl,"-",version,"-",arch,SLASH,"install.log",NULL);
  char* dist_path;
  int pos=position_char("-",impl);
  if(pos!=-1) {
    impl=subseq(impl,0,pos);
  }else
    impl=q(impl);
  dist_path=cat(home,"src",SLASH,impl,"-",version,"-",arch,SLASH,NULL);
  printf("Extracting archive. %s to %s\n",archive,dist_path);
  archive=s_cat(q(home),q("archives"),q(SLASH),archive,NULL);
  delete_directory(dist_path,1);
  ensure_directories_exist(dist_path);
  ensure_directories_exist(log_path);

  char* cmd=cat("start /wait msiexec.exe /a \"",
                archive,
                "\" targetdir=\"",
                dist_path,
                "\" /qn /lv ",
                "\"",
                log_path,
                "\"",
                NULL);
  ret=system(cmd);
  s(impl);
  s(dist_path);
  s(log_path);
  s(archive);
  s(cmd),s(home),s(version),s(arch);
  return !ret;
}

int sbcl_bin_install(struct install_options* param) {
  char* impl=param->impl;
  char* version=param->version;
  char* home= homedir();
  char* str;
  char* version_num= q(version);
  int ret;
  str=cat("echo f|xcopy \"",
          home,"src\\sbcl-",version,"-",arch,"\\PFiles\\Steel Bank Common Lisp\\",version_num,"\\sbcl.exe\" \"",
          home,"impls\\sbcl-",version,"-",arch,"\\bin\\sbcl.exe\" >NUL",NULL);
  ret=system(str);s(str);
  if(!ret) return 0;
  str=cat("echo f|xcopy \"",
          home,"src\\sbcl-",version,"-",arch,"\\PFiles\\Steel Bank Common Lisp\\",version_num,"\\sbcl.core\" \"",
          home,"impls\\sbcl-",version,"-",arch,"\\lib\\sbcl\\sbcl.core\" >NUL",NULL);
  ret=system(str);s(str);
  if(!ret) return 0;
  str=cat("echo d|xcopy \"",
          home,"src\\sbcl-",version,"-",arch,"\\PFiles\\Steel Bank Common Lisp\\",version_num,"\\contrib\" \"",
          home,"impls\\sbcl-",version,"-",arch,"\\lib\\sbcl\\contrib\" >NUL",NULL);
  ret=system(str);
  s(str),s(arch),s(home);
  if(!ret) return 0;
  return 1;
}
#endif

int sbcl_install(struct install_options* param) {
#ifndef _WIN32
  int ret=1;
  char* home= homedir();
  char* impl=param->impl;
  char* version=param->version;
  char* impl_path= cat(home,"impls",SLASH,param->arch,SLASH,param->os,SLASH,impl,SLASH,version,NULL);
  char* src=param->expand_path;
  char* sbcl_home=cat(impl_path,"/lib/sbcl",NULL);
  char* install_root=q(impl_path);
  char* log_path=cat(home,"impls/log/",impl,"-",version,"/install.log",NULL);
  printf("installing %s/%s ",impl,version);
  ensure_directories_exist(impl_path);
  ensure_directories_exist(log_path);
  change_directory(src);
  setenv("SBCL_HOME",sbcl_home,1);
  setenv("INSTALL_ROOT",install_root,1);
  
  if(system_redirect("sh install.sh",log_path)==-1) {
    ret=0;
  }
  s(home),s(impl_path),s(sbcl_home),s(install_root),s(log_path);
  printf("done.\n");
  return ret;
#else

#endif
}

install_cmds install_sbcl_bin_full[]={
  sbcl_version_bin,
  start,
  download,
#ifndef _WIN32
  expand,
  sbcl_install,
#else
  sbcl_bin_expand,
  sbcl_bin_install,
#endif
  NULL
};

struct install_impls impls_sbcl_bin={ "sbcl-bin", install_sbcl_bin_full,sbcl_uri_bin,sbcl_bin_extention,0};
