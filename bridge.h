#include <AppKit/AppKit.h>

AXError _AXUIElementGetWindow(AXUIElementRef element, uint32_t *identifier);

const uint32_t kCPSUserGenerated = 0x200;
CGError _SLPSGetFrontProcess(ProcessSerialNumber *psn);
CGError _SLPSSetFrontProcessWithOptions(ProcessSerialNumber *psn, uint32_t wid, uint32_t mode);
CGError SLPSPostEventRecordTo(ProcessSerialNumber *psn, uint8_t *bytes);
CGError SLSGetConnectionPSN(int32_t cid, ProcessSerialNumber *psn);
CGError SLSGetWindowOwner(int32_t cid, uint32_t wid, int32_t *wcid);
int32_t SLSMainConnectionID(void);
