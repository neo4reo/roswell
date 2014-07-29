#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifndef _WIN32
#include <pwd.h>
#include <unistd.h>
#endif
#ifdef HAVE_SYS_STAT_H
#include <sys/stat.h>
#endif

#include <stdarg.h>

char* q(const char* orig) {
  char* ret= (char*)malloc(strlen(orig)+1);
  strcpy(ret,orig);
  return ret;
}

void s(char* f) {
  free(f);
}

char* s_cat2(char* a,char* b) {
  char* ret= (char*)malloc(strlen(a)+strlen(b)+1);
  strcpy(ret,a);
  strcat(ret,b);
  s(a);
  s(b);
  return ret;
}

char* s_cat(char* first,...)
{
  char* ret=first;
  char* i;
  va_list list;
  va_start(list,first);

  for(i=va_arg( list , char*);i!=NULL;i=va_arg( list , char*)) {
    ret=s_cat2(ret,i);
  }
  va_end(list);
	
  return ret;
  
}

char* cat(char* first,...)
{
  char* ret=q(first);
  char* i;
  va_list list;
  va_start(list,first);

  for(i=va_arg( list , char*);i!=NULL;i=va_arg( list , char*)) {
    ret=s_cat2(ret,q(i));
  }
  va_end(list);
	
  return ret;
}
char* subseq(char* base,int beg,int end)
{
  int len=-1;
  int i;
  char* ret;
  if(0>beg) {
    if(0>len) {
      len=strlen(base);
    }
    beg=len+beg;
  }
  if(0>=end) {
    if(0>len) {
      len=strlen(base);
    }
    end=len+end;
  }
  if(end<=beg)
    return NULL;
  ret=malloc(end-beg+1);
  for(i=0;i<end-beg;++i) {
    ret[i]=base[i+beg];
  }
  ret[i]='\0';
  return ret;
}

char* remove_char(char* items,char* orig)
{
  int i,j,k;
  int found=0;
  char* ret;
  /* count removed*/
  for(j=0;orig[j]!='\0';++j) {
    for(i=0;items[i]!='\0';++i) {
      if(items[i]==orig[j]){
	++found;
	break;
      }
    }
  }
  ret=malloc(j+1-found);
  for(j=0,k=0;orig[j]!='\0';++j,++k) {
    for(i=0;items[i]!='\0';++i) {
      ret[k]=orig[j];
      if(items[i]==orig[j]){
	--k;
	break;
      }
    }
  }
  ret[k]='\0';
  return ret;
}

int position_char(char* items,char* seq) {
  int i,j;
  for(i=0;seq[i]!='\0';++i) {
    for(j=0;items[j]!='\0';++j) {
      if(seq[i]==items[j])
	return i;
    }
  }
  return -1;
}

char* substitute_char(char new,char old,char* seq) {
  int i;
  for(i=0;seq[i]!='\0';++i) {
    if(seq[i]==old)
      seq[i]=new;
  }
  return seq;
}

char* upcase(char* orig) {
  int i;
  for(i=0;orig[i]!='\0';++i) {
    if('a'<=orig[i] && orig[i]<='z')
      orig[i]=orig[i]-'a'+'A';
  }
  return orig;
}

char* downcase(char* orig) {
  int i;
  for(i=0;orig[i]!='\0';++i) {
    if('A'<=orig[i] && orig[i]<='Z')
      orig[i]=orig[i]-'A'+'a';
  }
  return orig;
}


char* append_trail_slash(char* str) {
  char* ret;
  if(str[strlen(str)-1]!='/') {
    ret=s_cat2(q(str),q("/"));
  }else {
    ret=q(str);
  }
  s(str);
  return ret;
}

char* homedir(void) {
#ifdef _WIN32
  return q("/dummy");
#else
  char *c;
  char *postfix="_HOME";
  struct passwd * pwd;
  char *env=NULL;
  int i;

  c=s_cat2(upcase(q(PACKAGE)),q(postfix));
  env=getenv(c);
  s(c);
  if(env) {
    return append_trail_slash(q(env));
  }
  pwd= getpwnam(getenv("USER"));
  if(pwd) {
    c=q(pwd->pw_dir);
  }else {
    /* error? */
    return NULL;
  }
  
  c=append_trail_slash(c);
  return s_cat(c,q("."),q(PACKAGE),q("/"),NULL);
#endif
}

char* pathname_directory(char* path) {
  int i;
  char* ret;
  for(i=strlen(path)-1;i>=0&&path[i]!='/';--i);
  ret=append_trail_slash(subseq(path,0,i));
  s(path);
  return ret;
}

char* ensure_directories_exist (char* path) {
  int len = strlen(path);
  if(len) {
    for(--len;(path[len]!='/'||len==-1);--len);
    path=subseq(path,0,len+1);
  }
  #ifndef _WIN32
  char* cmd=s_cat2(q("mkdir -p "),path);
  #else
  char* cmd=q("");
  #endif
  if(system(cmd)==-1) {
    printf("failed:%s\n",cmd);
    return NULL;
  };
  s(cmd);
  return path;
}

int directory_exist_p (char* path) {
#ifdef HAVE_SYS_STAT_H
  struct stat sb;
  int ret=0;
  if (stat(path, &sb) == 0 && S_ISDIR(sb.st_mode)) {
    ret=1;
  }
  return ret;
#else
#  error not imprement directory_exist_p  
#endif
}

int change_directory(const char* path) {
#ifndef _WIN32
  return chdir(path);
#else
  return _chdir(path);
#endif  
}

int delete_directory(char* pathspec,int recursive) {
#ifndef _WIN32
  char* cmd;
  int ret;
  if(recursive) {
    cmd=s_cat2(q("rm -rf "),q(pathspec));
  }else {
    cmd=s_cat2(q("rmdir "),q(pathspec));
  }
  ret=system(cmd);
  s(cmd);
  if(ret==-1) {
    return 0;
  }else {
    return 1;
  }
#else
  #error not implemented delete_directory
#endif  
}

int delete_file(char* pathspec) {
#ifndef _WIN32
  char* cmd;
  int ret;
  cmd=s_cat2(q("rm -f "),q(pathspec));
  ret=system(cmd);
  s(cmd);
  if(ret==-1) {
    return 0;
  }else {
    return 1;
  }
#else
  #error not implemented delete_file
#endif  
}

void touch(char* path) {
#ifndef _WIN32
  char* cmd=s_cat2(q("touch "),q(path));
#else
  char* cmd=q("");
#endif
  if(system(cmd)==-1){
  };
  s(cmd);
}

char* system_(char* cmd) {
#ifndef _WIN32
  FILE *fp;
  char buf[256];
  char* s=q("");
  if((fp=popen(cmd,"r")) ==NULL) {
    printf("Error:%s\n",cmd);
    exit(EXIT_FAILURE);
  }
  while(fgets(buf,256,fp) !=NULL) {
    s=s_cat2(s,q(buf));
  }
  (void)pclose(fp);
  return s;
#else
#endif
}

char* uname(void) {
  char *p=system_("uname");
  char *p2;
  p2=remove_char("\r\n",p);
  s(p);
  return downcase(p2);
}

char* uname_m(void) {
  char *p=system_("uname -m");
  char *p2;
  p2=remove_char("\r\n",p);
  s(p);
  return substitute_char('-','_',p2);
}
char* which(char* cmd) {
  char* which_cmd=cat("command -v \"",cmd,"\"",NULL);
  char* p=system_(which_cmd);
  char* p2=remove_char("\r\n",p);
  s(p),s(which_cmd);
  return p2;
}
