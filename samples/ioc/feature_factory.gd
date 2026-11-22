@Configuration
class_name FeatureFactory
extends RefCounted


@ConditionalOnFeature(feature="editor")
@Component
func editor_gate() -> EditorGate:
	return EditorGate.new()


@ConditionalOnFeature(feature="template")
@Component
func template_gate() -> TemplateGate:
	return TemplateGate.new()
