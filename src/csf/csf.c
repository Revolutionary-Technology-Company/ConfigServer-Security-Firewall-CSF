/*
	# #
	#   @app                ConfigServer Firewall & Security (CSF)
	#                       Login Failure Daemon (LFD)
	#   @website            https://configserver.shop
	#   @docs               https://docs.configserver.shop
	#   @download           https://download.configserver.shop
	#   @repo               https://github.com/orgs/Revolutionary-Technology-Company/
	#   @copyright          Copyright (C) 2025-2026 Dr. Correo Hofstad
	#                       Copyright (C) 2025-2026 Dr. Cory 'Aetherinox' Hofstad Jr.
	#                       Copyright (C) 2025-2026 Revolutionary Technology https://revolutionarytechnology.net
	#                       Copyright (C) 2006-2025 Jonathan Michaelson
	#                       Copyright (C) 2006-2025 Way to the Web Ltd.
	#   @license            GPLv3
	#   @updated            09.26.2025
	#   
	#   This program is free software; you can redistribute it and/or modify
	#   it under the terms of the GNU General Public License as published by
	#   the Free Software Foundation; either version 3 of the License, or (at
	#   your option) any later version.
	# #
*/
#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>
#include <pwd.h>

int main(void)
{
	FILE *adminFile;
	FILE *resellerFile;
	uid_t ruid;
	char name[100];
	struct passwd *pw;
	int admin = 0;
	int reseller = 0;

	setenv("CSF_RESELLER", "", 1);
	ruid = getuid();
	pw = getpwuid(ruid);

	adminFile=fopen ("/usr/local/directadmin/data/admin/admin.list","r");
	if (adminFile!=NULL)
	{
		while(fgets(name,100,adminFile) != NULL)
		{
			int end = strlen(name) - 1;
			if (end >= 0 && name[end] == '\n') name[end] = '\0';
			if (strcmp(pw->pw_name, name) == 0) admin = 1;
		}
		fclose(adminFile);
	}

	if (admin == 1)
	{
		setuid(0);
		setgid(0);
        // Use execl for safer argument handling on modern Linux
		execl("/usr/local/directadmin/plugins/csf/exec/da_csf.cgi", "da_csf.cgi", (char *)0);
	} else {
		resellerFile=fopen ("/usr/local/directadmin/data/admin/reseller.list","r");
		if (resellerFile!=NULL)
		{
			while(fgets(name,100,resellerFile) != NULL)
			{
				int end = strlen(name) - 1;
				if (end >= 0 && name[end] == '\n') name[end] = '\0';
				if (strcmp(pw->pw_name, name) == 0)
				{
					reseller = 1;
					setenv("CSF_RESELLER", pw->pw_name, 1);
				}
			}
			fclose(resellerFile);
		}
		if (reseller == 1)
		{
			setuid(0);
			setgid(0);
            // Use execl for safer argument handling on modern Linux
			execl("/usr/local/directadmin/plugins/csf/exec/da_csf_reseller.cgi", "da_csf_reseller.cgi", (char *)0);
		} else {
			printf("Permission denied [User:%s UID:%d]\n", pw->pw_name, ruid);
		}
	}

	return 0;
}