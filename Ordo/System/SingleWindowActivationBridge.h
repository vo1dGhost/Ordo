#ifndef ORDO_SINGLE_WINDOW_ACTIVATION_BRIDGE_H
#define ORDO_SINGLE_WINDOW_ACTIVATION_BRIDGE_H

#include <ApplicationServices/ApplicationServices.h>
#include <sys/types.h>

extern const OptionBits OrdoSingleWindowActivationOptions;
OSStatus OrdoActivateFrontWindowForPID(pid_t pid);

#endif
