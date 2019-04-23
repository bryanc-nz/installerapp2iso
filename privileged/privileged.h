//
//  privileged.h
//
//  Created by Bryan Christianson on 19/03/17.
//  Copyright © 2017 Rodney Truck Parts Ltd. All rights reserved.
//
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

#ifndef privileged_h
#define privileged_h

#include <Security/Security.h>

int auth_system(AuthorizationRef auth, const char *cmd);
AuthorizationRef authorise(const char *prompt);
int AuthorizedCommand(AuthorizationRef auth, const char *cmd, const char *args[]);

#endif /* privileged_h */
