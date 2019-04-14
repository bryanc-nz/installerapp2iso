//
//  privileged.h
//
//  Created by Bryan Christianson on 19/03/17.
//  Copyright © 2017 Rodney Truck Parts Ltd. All rights reserved.
//

#ifndef privileged_h
#define privileged_h

#include <Security/Security.h>

int auth_system(AuthorizationRef auth, const char *cmd);
AuthorizationRef authorise(const char *prompt);
int AuthorizedCommand(AuthorizationRef auth, const char *cmd, const char *args[]);

#endif /* privileged_h */
