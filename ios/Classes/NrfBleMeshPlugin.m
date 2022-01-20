#import "NrfBleMeshPlugin.h"
#if __has_include(<nrf_ble_mesh_plugin/nrf_ble_mesh_plugin-Swift.h>)
#import <nrf_ble_mesh_plugin/nrf_ble_mesh_plugin-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "nrf_ble_mesh_plugin-Swift.h"
#endif

@implementation NrfBleMeshPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftNrfBleMeshPlugin registerWithRegistrar:registrar];
}
@end
