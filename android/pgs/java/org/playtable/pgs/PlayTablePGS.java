package org.playtable.pgs;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Base64;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.gms.games.AchievementsClient;
import com.google.android.gms.games.EventsClient;
import com.google.android.gms.games.LeaderboardsClient;
import com.google.android.gms.games.PlayGames;
import com.google.android.gms.games.PlayGamesSdk;
import com.google.android.gms.games.Player;
import com.google.android.gms.games.SnapshotsClient;
import com.google.android.gms.games.snapshot.Snapshot;
import com.google.android.gms.games.snapshot.SnapshotMetadataChange;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.IOException;
import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

/**
 * Ponte entre o PlayTable e o Google Play Games Services v2.
 *
 * <p>O lado GDScript (core/services/PlayGamesManager.gd) cuida da politica --
 * o que enviar, quando, e o que fazer offline. Esta classe so traduz chamada em
 * chamada do SDK e devolve o resultado por sinal. Nenhuma regra de jogo mora
 * aqui.
 *
 * <p>Dois pontos que costumam quebrar integracao de PGS e que estao resolvidos
 * aqui de proposito:
 *
 * <ol>
 *   <li><b>Nada e sincrono.</b> Toda chamada do SDK devolve Task. O GDScript
 *       nunca espera retorno: pede e escuta o sinal. Assim uma falha de rede
 *       nunca trava o quadro.
 *   <li><b>Falha e avisada.</b> Cada operacao emite sinal de resultado, com
 *       sucesso ou fracasso. A integracao anterior chamava e presumia que tinha
 *       dado certo, entao um id invalido -- que o servidor recusa em silencio --
 *       parecia funcionar.
 * </ol>
 */
public class PlayTablePGS extends GodotPlugin {

	private static final String TAG = "PlayTablePGS";

	/** Sidekick exige Android 13 (API 33) e aparelho com folga de memoria. */
	private static final int SIDEKICK_MIN_SDK = Build.VERSION_CODES.TIRAMISU;
	private static final long SIDEKICK_MIN_RAM_BYTES = 3L * 1024L * 1024L * 1024L;

	private boolean initialized = false;
	private boolean authenticated = false;

	public PlayTablePGS(Godot godot) {
		super(godot);
	}

	@NonNull
	@Override
	public String getPluginName() {
		return "PlayTablePGS";
	}

	@NonNull
	@Override
	public Set<SignalInfo> getPluginSignals() {
		return new HashSet<>(Arrays.asList(
			new SignalInfo("pgs_signed_in", String.class, String.class),
			new SignalInfo("pgs_sign_in_failed", String.class),
			new SignalInfo("pgs_achievement_result", String.class, Boolean.class),
			new SignalInfo("pgs_score_result", String.class, Boolean.class),
			new SignalInfo("pgs_snapshot_loaded", String.class),
			new SignalInfo("pgs_snapshot_saved", Boolean.class, String.class),
			new SignalInfo("pgs_snapshot_conflict", String.class, String.class, String.class)
		));
	}

	/**
	 * PGS v2 exige inicializar o SDK antes de qualquer client -- sem isto a
	 * primeira chamada estoura com IllegalStateException.
	 *
	 * <p>Feito sob demanda em vez de num hook de ciclo de vida: a assinatura
	 * dos hooks do GodotPlugin muda entre versoes da engine (o {@code
	 * onMainCreate} de hoje devolve View, nao void), e uma quebra ali derruba a
	 * compilacao do APK inteiro. Inicializar na primeira chamada custa um
	 * booleano e vale para qualquer versao.
	 */
	private boolean ensureInitialized() {
		if (initialized) {
			return true;
		}
		Activity activity = getActivity();
		if (activity == null) {
			return false;
		}
		PlayGamesSdk.initialize(activity);
		initialized = true;
		return true;
	}

	// ---------------------------------------------------------------- login

	/**
	 * Login automatico do PGS v2. Nao abre tela: se o jogador ja aceitou o Play
	 * Games neste aparelho, resolve sozinho; senao devolve falha e o jogo segue
	 * offline sem incomodar ninguem.
	 */
	@UsedByGodot
	public void signInSilently() {
		if (!ensureInitialized()) {
			emitSignal("pgs_sign_in_failed", "SDK nao inicializado");
			return;
		}
		Activity activity = getActivity();
		PlayGames.getGamesSignInClient(activity).isAuthenticated()
			.addOnCompleteListener(task -> {
				boolean ok = task.isSuccessful() && task.getResult().isAuthenticated();
				if (ok) {
					fetchPlayer();
				} else {
					authenticated = false;
					emitSignal("pgs_sign_in_failed", "nao autenticado");
				}
			});
	}

	/** Login com tela, para o botao explicito na tela de perfil. */
	@UsedByGodot
	public void signIn() {
		if (!ensureInitialized()) {
			emitSignal("pgs_sign_in_failed", "SDK nao inicializado");
			return;
		}
		Activity activity = getActivity();
		PlayGames.getGamesSignInClient(activity).signIn()
			.addOnCompleteListener(task -> {
				if (task.isSuccessful() && task.getResult().isAuthenticated()) {
					fetchPlayer();
				} else {
					authenticated = false;
					emitSignal("pgs_sign_in_failed", errorOf(task.getException()));
				}
			});
	}

	@UsedByGodot
	public boolean isAuthenticated() {
		return authenticated;
	}

	private void fetchPlayer() {
		Activity activity = getActivity();
		if (activity == null) {
			return;
		}
		PlayGames.getPlayersClient(activity).getCurrentPlayer()
			.addOnCompleteListener(task -> {
				authenticated = true;
				if (task.isSuccessful() && task.getResult() != null) {
					Player p = task.getResult();
					emitSignal("pgs_signed_in", p.getPlayerId(), p.getDisplayName());
				} else {
					// Autenticado mas sem perfil legivel: ainda da para enviar
					// conquista e placar, entao nao e falha de login.
					emitSignal("pgs_signed_in", "", "");
				}
			});
	}

	// ----------------------------------------------------------- conquistas

	@UsedByGodot
	public void unlockAchievement(String achievementId) {
		AchievementsClient client = achievements();
		if (client == null) {
			emitSignal("pgs_achievement_result", achievementId, false);
			return;
		}
		client.unlockImmediate(achievementId).addOnCompleteListener(
			task -> emitSignal("pgs_achievement_result", achievementId, task.isSuccessful()));
	}

	@UsedByGodot
	public void incrementAchievement(String achievementId, int steps) {
		AchievementsClient client = achievements();
		if (client == null) {
			emitSignal("pgs_achievement_result", achievementId, false);
			return;
		}
		client.incrementImmediate(achievementId, steps).addOnCompleteListener(
			task -> emitSignal("pgs_achievement_result", achievementId, task.isSuccessful()));
	}

	/**
	 * Define o numero absoluto de passos.
	 *
	 * <p>Preferido ao incremento porque a fila offline do lado GDScript colapsa
	 * eventos repetidos: se dez partidas viraram uma entrada, incrementar
	 * mandaria um passo e perderia nove. O valor absoluto chega certo em
	 * qualquer ordem, e o servidor ignora valor menor que o ja registrado.
	 */
	@UsedByGodot
	public void setAchievementSteps(String achievementId, int steps) {
		AchievementsClient client = achievements();
		if (client == null) {
			emitSignal("pgs_achievement_result", achievementId, false);
			return;
		}
		client.setStepsImmediate(achievementId, steps).addOnCompleteListener(
			task -> emitSignal("pgs_achievement_result", achievementId, task.isSuccessful()));
	}

	@UsedByGodot
	public void showAchievements() {
		AchievementsClient client = achievements();
		if (client == null) {
			return;
		}
		client.getAchievementsIntent().addOnSuccessListener(this::startOverlay);
	}

	// -------------------------------------------------------------- placares

	@UsedByGodot
	public void submitScore(String leaderboardId, int score) {
		LeaderboardsClient client = leaderboards();
		if (client == null) {
			emitSignal("pgs_score_result", leaderboardId, false);
			return;
		}
		client.submitScoreImmediate(leaderboardId, score).addOnCompleteListener(
			task -> emitSignal("pgs_score_result", leaderboardId, task.isSuccessful()));
	}

	@UsedByGodot
	public void showLeaderboard(String leaderboardId) {
		LeaderboardsClient client = leaderboards();
		if (client == null) {
			return;
		}
		client.getLeaderboardIntent(leaderboardId).addOnSuccessListener(this::startOverlay);
	}

	@UsedByGodot
	public void showAllLeaderboards() {
		LeaderboardsClient client = leaderboards();
		if (client == null) {
			return;
		}
		client.getAllLeaderboardsIntent().addOnSuccessListener(this::startOverlay);
	}

	// --------------------------------------------------------------- eventos

	@UsedByGodot
	public void submitEvent(String eventId, int amount) {
		Activity activity = getActivity();
		if (activity == null || !authenticated) {
			return;
		}
		EventsClient client = PlayGames.getEventsClient(activity);
		client.increment(eventId, amount);
	}

	// ------------------------------------------------------------- snapshots

	/**
	 * Le o snapshot de progresso. Emite {@code pgs_snapshot_loaded} com o
	 * conteudo em base64, ou {@code pgs_snapshot_conflict} quando dois
	 * aparelhos gravaram por cima um do outro.
	 *
	 * <p>A politica e MANUAL de proposito: resolver automaticamente pelo mais
	 * recente descartaria o progresso do outro aparelho. Quem junta os dois
	 * lados e o CloudSaveSync, que sabe que contador vale o maior e que
	 * conquista vale a uniao.
	 */
	@UsedByGodot
	public void loadSnapshot(String snapshotName) {
		SnapshotsClient client = snapshots();
		if (client == null) {
			emitSignal("pgs_snapshot_loaded", "");
			return;
		}
		client.open(snapshotName, true, SnapshotsClient.RESOLUTION_POLICY_MANUAL)
			.addOnCompleteListener(task -> {
				if (!task.isSuccessful() || task.getResult() == null) {
					emitSignal("pgs_snapshot_loaded", "");
					return;
				}
				SnapshotsClient.DataOrConflict<Snapshot> result = task.getResult();
				if (result.isConflict()) {
					SnapshotsClient.SnapshotConflict conflict = result.getConflict();
					emitSignal("pgs_snapshot_conflict",
						conflict.getConflictId(),
						readSnapshot(conflict.getSnapshot()),
						readSnapshot(conflict.getConflictingSnapshot()));
					return;
				}
				emitSignal("pgs_snapshot_loaded", readSnapshot(result.getData()));
			});
	}

	@UsedByGodot
	public void saveSnapshot(String snapshotName, String description, String base64Data) {
		SnapshotsClient client = snapshots();
		if (client == null) {
			emitSignal("pgs_snapshot_saved", false, "sem sessao");
			return;
		}
		byte[] bytes = decode(base64Data);
		client.open(snapshotName, true, SnapshotsClient.RESOLUTION_POLICY_MANUAL)
			.addOnCompleteListener(task -> {
				if (!task.isSuccessful() || task.getResult() == null || task.getResult().isConflict()) {
					emitSignal("pgs_snapshot_saved", false, "snapshot indisponivel ou em conflito");
					return;
				}
				writeAndCommit(client, task.getResult().getData(), bytes, description);
			});
	}

	@UsedByGodot
	public void resolveSnapshotConflict(String conflictId, String base64Data) {
		SnapshotsClient client = snapshots();
		if (client == null) {
			emitSignal("pgs_snapshot_saved", false, "sem sessao");
			return;
		}
		byte[] bytes = decode(base64Data);
		client.open(conflictId, true, SnapshotsClient.RESOLUTION_POLICY_MANUAL)
			.addOnCompleteListener(task -> {
				if (!task.isSuccessful() || task.getResult() == null) {
					emitSignal("pgs_snapshot_saved", false, "conflito nao resolvido");
					return;
				}
				SnapshotsClient.DataOrConflict<Snapshot> result = task.getResult();
				Snapshot alvo = result.isConflict()
					? result.getConflict().getSnapshot()
					: result.getData();
				writeAndCommit(client, alvo, bytes, "Merge automatico de progresso");
			});
	}

	private void writeAndCommit(SnapshotsClient client, Snapshot snapshot, byte[] bytes, String description) {
		snapshot.getSnapshotContents().writeBytes(bytes);
		SnapshotMetadataChange change = new SnapshotMetadataChange.Builder()
			.setDescription(description)
			.build();
		client.commitAndClose(snapshot, change).addOnCompleteListener(
			task -> emitSignal("pgs_snapshot_saved", task.isSuccessful(),
				task.isSuccessful() ? "ok" : errorOf(task.getException())));
	}

	private String readSnapshot(@Nullable Snapshot snapshot) {
		if (snapshot == null) {
			return "";
		}
		try {
			byte[] bytes = snapshot.getSnapshotContents().readFully();
			return bytes == null ? "" : Base64.encodeToString(bytes, Base64.NO_WRAP);
		} catch (IOException e) {
			Log.w(TAG, "falha lendo snapshot", e);
			return "";
		}
	}

	private byte[] decode(String base64Data) {
		if (base64Data == null || base64Data.isEmpty()) {
			return new byte[0];
		}
		try {
			return Base64.decode(base64Data, Base64.NO_WRAP);
		} catch (IllegalArgumentException e) {
			Log.w(TAG, "base64 invalido vindo do GDScript", e);
			return new byte[0];
		}
	}

	// -------------------------------------------------------------- sidekick

	/**
	 * O overlay Sidekick so existe em Android 13+ e some em aparelho apertado
	 * de memoria. A versao anterior devolvia {@code true} para qualquer Android
	 * e a interface prometia um recurso que nao abriria.
	 */
	@UsedByGodot
	public boolean isSidekickSupported() {
		if (Build.VERSION.SDK_INT < SIDEKICK_MIN_SDK) {
			return false;
		}
		Activity activity = getActivity();
		if (activity == null) {
			return false;
		}
		ActivityManager am = (ActivityManager) activity.getSystemService(Context.ACTIVITY_SERVICE);
		if (am == null) {
			return false;
		}
		ActivityManager.MemoryInfo info = new ActivityManager.MemoryInfo();
		am.getMemoryInfo(info);
		return info.totalMem >= SIDEKICK_MIN_RAM_BYTES;
	}

	// ------------------------------------------------------------ utilitarios

	@Nullable
	private AchievementsClient achievements() {
		Activity activity = getActivity();
		return (activity != null && authenticated) ? PlayGames.getAchievementsClient(activity) : null;
	}

	@Nullable
	private LeaderboardsClient leaderboards() {
		Activity activity = getActivity();
		return (activity != null && authenticated) ? PlayGames.getLeaderboardsClient(activity) : null;
	}

	@Nullable
	private SnapshotsClient snapshots() {
		Activity activity = getActivity();
		return (activity != null && authenticated) ? PlayGames.getSnapshotsClient(activity) : null;
	}

	/** Os paineis do Play Games sao Activities do proprio Google. */
	private void startOverlay(Intent intent) {
		Activity activity = getActivity();
		if (activity != null && intent != null) {
			activity.startActivityForResult(intent, 9001);
		}
	}

	private String errorOf(@Nullable Exception e) {
		return e == null ? "erro desconhecido" : String.valueOf(e.getMessage());
	}
}
