@Configuration
@ConfigurationPropertiesScan(root="res://samples/ioc")
class_name SettingsScan
extends RefCounted

## Opts in to binding. Classes outside this root stay unregistered even
## when they carry @ConfigurationProperties.
