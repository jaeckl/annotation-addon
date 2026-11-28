@ConditionalOnProperty(key="ioc/primary_fixtures", having_value="yes")
@Component
class_name PrimaryBag
extends RefCounted

@Inject var kinds: Array[PrimaryKind]
