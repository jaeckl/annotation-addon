@ConditionalOnProperty(key="ioc/eager_broken", having_value="yes")
@Eager
@RunScope
@Component
class_name EagerBroken
extends RefCounted

@Inject var need: EagerNeed
