//
//  privileged.c
//
//  Created by Bryan Christianson on 19/03/17.
//  Copyright © 2017 Rodney Truck Parts Ltd. All rights reserved.
//

#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

#include <Security/Security.h>

#include "privileged.h"

int auth_system(AuthorizationRef auth, const char *cmd)
{
	char command[4096];

	const char *args[] = {
		"-c",
		command,
		NULL
	};

	snprintf(command, sizeof(command), "%s", cmd);

	return AuthorizedCommand(auth, "/bin/sh", args);
}

AuthorizationRef authorise(const char *prompt)
{
	AuthorizationRef myAuthorizationRef = NULL;
	OSStatus err;

	err = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &myAuthorizationRef);
	if (err != errAuthorizationSuccess) {
		return NULL;
	}

	AuthorizationItem myItems = {kAuthorizationRightExecute, 0, NULL, 0};
	AuthorizationRights myRights = {1, &myItems};
	AuthorizationFlags myFlags = (AuthorizationFlags)
									(
										kAuthorizationFlagInteractionAllowed |
										kAuthorizationFlagExtendRights |
										kAuthorizationFlagPreAuthorize
									);

	AuthorizationEnvironment authEnv;
	AuthorizationItem kAuthEnv[1];
	authEnv.items = kAuthEnv;

	authEnv.count = 0;
	if (prompt != NULL && strlen(prompt) > 0) {
		kAuthEnv[0].name = kAuthorizationEnvironmentPrompt;
		kAuthEnv[0].valueLength = strlen(prompt);
		kAuthEnv[0].value = (void *)prompt;
		kAuthEnv[0].flags = 0;

		authEnv.count = 1;
	}

	err = AuthorizationCopyRights(myAuthorizationRef, &myRights, &authEnv, myFlags, NULL);
	if (err != errAuthorizationSuccess) {
		goto fail;
	}

	return myAuthorizationRef;

fail:
	AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDefaults);
	return NULL;
}

int AuthorizedCommand(AuthorizationRef auth, const char *cmd, const char *args[])
{
	int pid, status;
	int ret = -1;
	FILE *ioPipe;

	typedef OSStatus (*aewp_t)(AuthorizationRef authorization,
								   const char *pathToTool,
						   AuthorizationFlags options,
								 char * const *arguments,
										 FILE **communicationsPipe);

	static aewp_t security_AuthorizationExecuteWithPrivileges = NULL;

	if (!security_AuthorizationExecuteWithPrivileges) {
		// On 10.7, AuthorizationExecuteWithPrivileges is deprecated. We want to still use it since there's no
		// good alternative (without requiring code signing). We'll look up the function through dyld and fail
		// if it is no longer accessible. If Apple removes the function entirely this will fail gracefully. If
		// they keep the function and throw some sort of exception, this won't fail gracefully, but that's a
		// risk we'll have to take for now.
		security_AuthorizationExecuteWithPrivileges = (aewp_t)dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges");
	}

	if (!security_AuthorizationExecuteWithPrivileges) goto fail;

	OSStatus err = security_AuthorizationExecuteWithPrivileges(
				auth,
				cmd,
				kAuthorizationFlagDefaults,
				(char * const *)args,
				&ioPipe);
	if (err != errAuthorizationSuccess) goto fail;

	while(1) {
		char buffer[1024];
		size_t bytesRead = fread(buffer, sizeof(char), 1024, ioPipe);
		if (bytesRead < 1) break;
		write(STDOUT_FILENO, buffer, bytesRead * sizeof(char));
	}
	pclose(ioPipe);

	// Wait until it's done
	pid = wait(&status);

	// We don't care about exit status as the destination most likely does not exist
	//if (pid == -1 || !WIFEXITED(status)) goto fail;

	ret = 0;

fail:
	return ret;
}

