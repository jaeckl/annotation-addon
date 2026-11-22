@ConditionalOnFeature(feature="template")
@Configuration
class_name TemplateFactory
extends RefCounted


@Component
func ghost() -> TemplateGhost:
	return TemplateGhost.new()
