extends JogosAudioService

## Autoload `AudioManager`: o serviço de áudio como singleton. Sem
## `class_name` (Godot 4.7 rejeita class_name igual ao nome do autoload).
## Quem prefere injeção instancia `JogosAudioService` direto.
