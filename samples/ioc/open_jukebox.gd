@ConditionalOnProperty(key="combat/enabled", having_value="true")
@ConditionalOnComponent(type_name="Jukebox")
@Component
class_name OpenJukebox
extends RefCounted
