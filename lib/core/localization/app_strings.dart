import '../constants/prompt_templates.dart';
import 'app_language.dart';

class AppStrings {
  AppStrings(this.language);

  final AppLanguage language;

  bool get isChinese => language == AppLanguage.chinese;

  String _t(String en, String zh) => isChinese ? zh : en;

  String get appName => _t('FitLog Agent', 'FitLog Agent');
  String get appNameShort => _t('FitLog', 'FitLog');
  String get nicknameLabel => _t('Nickname', '昵称');
  String get nicknameHint => _t('Used for the Home greeting', '用于首页问候语');
  String get nicknameFallback => _t('there', '你');
  String get morningGreeting => _t('Morning', '早上好');
  String get afternoonGreeting => _t('Afternoon', '下午好');
  String get eveningGreeting => _t('Evening', '晚上好');
  String homeGreeting(String greeting, String nickname) =>
      isChinese ? '$greeting，$nickname！' : '$greeting, $nickname!';
  String get homeConsistencyHint => _t("Let's stay consistent.", '今天也稳稳记录。');
  String get todayRecordsTitle => _t("Today's Records", '今日记录');
  String get strategyContextTitle => _t('Current Strategy', '当前策略');
  String get viewAll => _t('View all', '查看全部');
  String get details => _t('Details', '详情');
  String get localFirstIdentityHint =>
      _t('Saved only on this device for your local UI.', '仅保存在本机，用于本地 UI 展示。');
  String get localFirstTipTitle => _t('Local-first', 'Local-first');
  String get localFirstAiBoundaryHint => _t(
    'AI outputs stay as drafts until you review and save them.',
    'AI 输出在你确认保存前都只是草稿。',
  );
  String foodRecordsSummary(int mealCount) =>
      _t('$mealCount meal${mealCount == 1 ? '' : 's'}', '已记录 $mealCount 餐');
  String workoutRecordsSummary(int sessionCount) => _t(
    '$sessionCount session${sessionCount == 1 ? '' : 's'}',
    '已记录 $sessionCount 次',
  );
  String macroProgressText(double current, double target) =>
      '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} g';
  String macroPercentText(double progress) => '${(progress * 100).round()}%';

  String get homeDashboardTitle => _t('Home / Daily Dashboard', '首页 / 每日看板');
  String get foodLogTitle => _t('Food Log', '饮食记录');
  String get workoutLogTitle => _t('Workout Log', '训练记录');
  String get profileSettingsTitle => _t('Profile & Settings', '资料与设置');

  String get navHome => _t('Home', '首页');
  String get navFood => _t('Food', '饮食');
  String get navAi => _t('AI', 'AI');
  String get navWorkout => _t('Workout', '训练');
  String get navProfile => _t('Profile', '我的');
  String get aiListening => _t("I'm listening", '我在听');
  String get aiListeningNameSeparator => _t(', ', '，');
  String get aiSignInRequired =>
      _t('Sign in to use FitLog AI', '登录后开始使用 FitLog AI');
  String get aiDisabledBody => _t(
    'You can draft a prompt now. Sending will be available after account, subscription, and AI Gateway are connected.',
    '你可以先写下想问的内容。账号、订阅和 AI Gateway 接通后才能发送。',
  );
  String get aiComposerHint => _t('Ask away with FitLog', '快问问 FitLog');
  String get aiSendTooltip => _t('Send', '发送');
  String get aiAttachTooltip => _t('Attach image', '添加图片');
  String get aiImageRequiresQwen =>
      _t('Image chat requires Qwen.', '图片对话需要使用千问。');
  String get aiImageOnlyMessage => _t('Please analyze this image.', '请分析这张图片。');
  String get aiImageLimitReached =>
      _t('You can attach up to 3 images.', '最多可添加 3 张图片。');
  String get aiFoodDraftCardTitle => _t('Food draft ready', '饮食草稿已生成');
  String aiFoodDraftCardSummary(String mealName, String calories) =>
      _t('$mealName · about $calories kcal', '$mealName · 约 $calories kcal');
  String get aiFoodDraftCardAction => _t('Review and confirm', '查看并确认饮食草稿');
  String get aiFoodDraftCardUnavailable =>
      _t('Draft unavailable. Please regenerate it.', '草稿不可用，请重新生成。');
  String get aiWorkoutDraftCardTitle => _t('Workout draft ready', '训练草稿已生成');
  String aiWorkoutDraftCardSummary(String recordName, int exerciseCount) => _t(
    '$recordName · $exerciseCount exercise${exerciseCount == 1 ? '' : 's'}',
    '$recordName · $exerciseCount 个动作',
  );
  String get aiWorkoutDraftCardAction => _t('Review and confirm', '查看并确认');
  String get aiWorkoutDraftCardUnavailable =>
      _t('Workout draft unavailable. Please regenerate it.', '训练草稿不可用，请重新生成。');
  String get aiWorkoutDraftReplaceTitle =>
      _t('Replace unsaved workout draft?', '替换未保存训练草稿？');
  String get aiWorkoutDraftReplaceMessage => _t(
    'You already have an unsaved workout draft. Replace it with this AI-generated draft?',
    '当前已有一条未保存训练草稿。要用这条 AI 生成的训练草稿替换它吗？',
  );
  String get aiWorkoutDraftReplaceAction => _t('Replace draft', '替换草稿');
  String get aiHistoryTooltip => _t('Chat history', '历史会话');
  String get aiHistoryTitle => _t('Chat history', '历史会话');
  String get aiHistorySignedOut => _t(
    'History will be available after cloud accounts and chat storage are implemented.',
    '云端账号和会话存储实现后，这里会显示历史会话。',
  );
  String get aiHistoryEmpty => _t('No chats yet.', '还没有会话。');
  String get aiNewChat => _t('New chat', '新会话');
  String get aiUntitledChat => _t('Untitled chat', '未命名会话');
  String get aiArchiveChat => _t('Archive chat', '归档会话');
  String get aiDeleteChat => _t('Delete chat', '删除会话');
  String get aiRenameChat => _t('Rename chat', '重命名会话');
  String get aiRenameChatEmpty => _t('Enter a chat title.', '请输入会话标题。');
  String get aiRenameChatFailed =>
      _t('Chat title could not be renamed.', '会话重命名失败。');
  String get aiDeleteChatConfirmTitle => _t('Delete chat?', '删除会话？');
  String aiDeleteChatConfirmBody(String title) => _t(
    'Delete "$title" from chat history? This cannot be undone.',
    '确认从历史会话中删除“$title”？此操作无法撤销。',
  );
  String get aiAccountTooltip => _t('Account and subscription', '账号与订阅');
  String get aiAccountComingSoon =>
      _t('Open account, subscription, and privacy settings.', '打开账号、订阅和隐私设置。');
  String get aiProviderChatGpt => _t('ChatGPT', 'ChatGPT');
  String get aiProviderQwen => _t('Qwen', '千问');
  String get aiSignedOutStatus => _t('Signed out', '未登录');
  String get aiAvailableStatus => _t('Ready', '可用');
  String get aiUnavailableStatus => _t('Off', '不可用');
  String get aiOfflineStatus => _t('Offline', '离线');
  String get aiPreparingStatus => _t('Preparing', '准备中');
  String get aiThinkingStatus => _t('Thinking', '思考中');
  String get phase2BackendNotConfigured => _t(
    'Supabase is not configured for this build. Start the app with SUPABASE_URL and SUPABASE_ANON_KEY to test login.',
    '当前构建未配置 Supabase。请使用 SUPABASE_URL 和 SUPABASE_ANON_KEY 启动后测试登录。',
  );
  String get profileSignInTitle =>
      _t('Sign in to manage your Profile', '登录后管理 Profile');
  String get profileSignInBody => _t(
    'Sign in to manage your Cloud Profile and cloud official records. Existing local history is never uploaded without confirmation.',
    '登录后管理云端 Profile 和云端正式记录。已有本机历史不会在未确认时上传。',
  );
  String get emailLabel => _t('Email', '邮箱');
  String get otpCodeLabel => _t('OTP code', '验证码');
  String get passwordLabel => _t('Password', '密码');
  String get confirmPasswordLabel => _t('Confirm password', '确认密码');
  String get sendOtp => _t('Send code', '发送验证码');
  String get signInToFitLog => _t('Sign in to FitLog', '登录 FitLog');
  String get signInAccount => _t('Sign in', '登录账号');
  String get createAccount => _t('Create account', '创建账号');
  String get imNewToFitLog => _t("I'm new to FitLog", '注册账号');
  String get alreadyHaveAccountSignIn =>
      _t('Already have an account? Sign in', '已有账号？登录');
  String get registrationCodeSent =>
      _t('Registration code sent. Check your email.', '注册验证码已发送，请检查邮箱。');
  String get passwordMismatch => _t('Passwords do not match.', '两次输入的密码不一致。');
  String get passwordTooShort =>
      _t('Use at least 8 characters for the password.', '密码至少需要 8 个字符。');
  String get emailRequired => _t('Please enter your email.', '请先填写邮箱。');
  String get passwordRequired => _t('Please enter your password.', '请填写密码。');
  String get otpRequired => _t('Please enter the code.', '请填写验证码。');
  String get signOut => _t('Sign out', '退出登录');
  String get phase2ErrorCodeLabel => _t('Error code', '错误码');
  String phase2ErrorMessage(String code) {
    switch (code) {
      case 'backend_not_configured':
        return phase2BackendNotConfigured;
      case 'invalid_credentials':
        return _t('Email or password is incorrect.', '邮箱或密码不正确。');
      case 'email_not_confirmed':
        return _t(
          'Please verify this email before signing in.',
          '请先完成邮箱验证后再登录。',
        );
      case 'email_already_registered':
        return _t(
          'This email is already registered. Sign in instead.',
          '该邮箱已注册，请直接登录。',
        );
      case 'otp_invalid_or_expired':
        return _t(
          'The code is incorrect or expired. Send a new code and try again.',
          '验证码不正确或已过期，请重新发送后再试。',
        );
      case 'auth_rate_limited':
        return _t(
          'Too many attempts. Please wait a moment and try again.',
          '尝试次数过多，请稍后再试。',
        );
      case 'auth_network_error':
        return _t(
          'Network connection failed. Check your connection and try again.',
          '网络连接失败，请检查网络后重试。',
        );
      case 'auth_required':
        return authRequired;
      case 'device_replaced':
        return _t(
          'This account was signed in on another device. Sign in again to take over.',
          '该账号已在另一台设备登录。请重新登录以接管。',
        );
      case 'active_device_rpc_missing':
        return _t(
          'Active-device functions are missing. Run the Phase 3 Supabase migration.',
          '缺少 active-device 云端函数，请运行 Phase 3 Supabase migration。',
        );
      case 'active_device_claim_failed':
      case 'active_device_assert_failed':
        return _t(
          'Device session could not be verified. Please sign in again.',
          '设备会话无法验证，请重新登录。',
        );
      case 'record_rls_denied':
        return _t(
          'Cloud record access was blocked by Supabase RLS.',
          '云端记录被 Supabase RLS 拦截。',
        );
      case 'record_network_error':
        return _t(
          'Network connection failed while saving cloud records.',
          '保存云端记录时网络连接失败。',
        );
      case 'record_schema_mismatch':
        return _t(
          'Cloud Records schema is incomplete. Run the Phase 3 Supabase migration.',
          'Cloud Records schema 不完整，请运行 Phase 3 Supabase migration。',
        );
      case 'cloud_record_missing':
        return _t(
          'This local cache row is not linked to a cloud record. Refresh from cloud and try again.',
          '这条本地缓存没有关联云端记录，请从云端刷新后再试。',
        );
      case 'body_metric_delete_failed':
        return _t(
          'Body record could not be deleted. Please try again.',
          '身体记录删除失败，请重试。',
        );
      case 'subscription_load_failed':
        return _t(
          'Subscription status could not be loaded. Retry after checking Supabase.',
          '订阅状态加载失败，请检查 Supabase 后重试。',
        );
      case 'invalid_or_expired_code':
        return _t('Invalid or expired code.', '兑换码无效或已过期。');
      case 'code_already_redeemed':
        return _t('Code already redeemed.', '该兑换码已使用。');
      case 'redeem_failed':
        return _t('Redeem failed. Please try again.', '兑换失败，请重试。');
      case 'local_context_save_failed':
        return _t(
          'Record-summary permission could not be updated. Please try again.',
          '用户记录摘要授权更新失败，请重试。',
        );
      case 'profile_load_failed':
        return _t(
          'Cloud Profile could not be loaded. Retry after checking Supabase.',
          '云端 Profile 加载失败，请检查 Supabase 后重试。',
        );
      case 'profile_fetch_failed':
        return _t(
          'Cloud Profile fetch failed. Check the Supabase project and policies.',
          '云端 Profile 读取失败，请检查 Supabase 项目和访问策略。',
        );
      case 'profile_table_missing':
        return _t(
          'Cloud Profile table is missing. Run the Phase 2 profile SQL.',
          '云端 Profile 表不存在，请运行 Phase 2 Profile SQL。',
        );
      case 'profile_schema_mismatch':
        return _t(
          'Cloud Profile fields are incomplete. Run the schema compatibility SQL.',
          '云端 Profile 字段不完整，请运行 schema 兼容 SQL。',
        );
      case 'profile_schema_type_mismatch':
        return _t(
          'Cloud Profile field types do not match. Install the latest APK and check the schema.',
          '云端 Profile 字段类型不匹配，请安装最新版 APK 并检查 schema。',
        );
      case 'profile_rls_denied':
        return _t(
          'Cloud Profile access was blocked by Supabase RLS. Check the login session and own-row policies.',
          '云端 Profile 被 Supabase RLS 拦截，请检查登录状态和 own-row policy。',
        );
      case 'profile_auth_expired':
        return _t(
          'Your sign-in session expired. Sign out and sign in again.',
          '登录会话已过期，请退出后重新登录。',
        );
      case 'profile_constraint_failed':
        return _t(
          'Cloud Profile data failed a database constraint. Check the saved values and schema.',
          '云端 Profile 数据未通过数据库约束，请检查保存值和 schema。',
        );
      case 'profile_save_no_row':
        return _t(
          'Cloud Profile saved without returning a row. Check Supabase RLS select policy.',
          '云端 Profile 保存后未返回数据行，请检查 Supabase RLS select policy。',
        );
      case 'profile_network_error':
        return _t(
          'Network connection failed while loading Cloud Profile.',
          '加载云端 Profile 时网络连接失败。',
        );
      case 'profile_save_failed':
        return _t(
          'Cloud Profile could not be saved. Please try again.',
          '云端 Profile 保存失败，请重试。',
        );
      case 'auth_failed':
        return _t('Sign-in failed. Please try again.', '登录失败，请重试。');
      default:
        return _t('Something went wrong. Please try again.', '操作失败，请重试。');
    }
  }

  String get completeCloudProfile =>
      _t('Complete Cloud Profile', '完善云端 Profile');
  String get createDefaultCloudProfile =>
      _t('Create default Cloud Profile', '创建默认云端 Profile');
  String get cloudProfileMissingBody => _t(
    'This account does not have a Cloud Profile yet. Create one before using Profile settings or AI personalization.',
    '这个账号还没有云端 Profile。请先创建后再使用资料设置或 AI 个性化。',
  );
  String get cloudProfileLoading =>
      _t('Loading Cloud Profile...', '正在加载云端 Profile...');
  String get cloudProfileOfflineReadonly => _t(
    'Offline: cached Profile can be viewed, but saving is disabled.',
    '离线状态：可以查看缓存 Profile，但不能保存修改。',
  );
  String get aiLocalContextPermissionTitle =>
      _t('Use record summaries for AI answers', '允许 AI 使用用户记录摘要');
  String get aiLocalContextPermissionBody => _t(
    'When enabled, later AI workflows may use necessary cloud summaries from confirmed food, workout, and body records. Full raw history is not uploaded by default.',
    '开启后，后续 AI workflow 可以使用已确认饮食、训练和身体记录的必要云端摘要。默认不会上传完整原始历史。',
  );
  String get subscriptionActive => _t('Subscription active', '订阅已生效');
  String get subscriptionInactive => _t('Subscription inactive', '订阅未生效');
  String get subscriptionUnavailable =>
      _t('Subscription unavailable', '订阅状态不可用');
  String get subscriptionTitle => _t('Subscription', '订阅');
  String get subscriptionStatusLabel => _t('Status', '状态');
  String get subscriptionPlanLabel => _t('Plan', '计划');
  String get subscriptionEndLabel => _t('End', '到期');
  String get subscriptionActiveShort => _t('Active', '已开启');
  String get subscriptionInactiveShort => _t('Inactive', '未开启');
  String get subscriptionUnavailableShort => _t('Unavailable', '不可用');
  String get refreshSubscription => _t('Refresh', '刷新');
  String get redeemCodeTitle => _t('Redeem code', '输入兑换码');
  String get redeemCodeLabel => _t('Code', '兑换码');
  String get redeemCodeAction => _t('Redeem', '兑换');
  String get redeemCodeRequired => _t('Enter a code.', '请输入兑换码。');
  String get redeemCodeSuccess => _t('Redeemed.', '兑换成功。');
  String get profileRequired => _t('Profile required', '需要先完善 Profile');
  String get aiGatewayPending =>
      _t('AI Gateway is not connected yet.', 'AI Gateway 尚未接通，暂时不能发送。');
  String get aiGatewayConnected =>
      _t('AI Gateway is connected.', 'AI Gateway 已接通。');
  String get aiGatewayTimeout =>
      _t('AI response timed out. Try again.', 'AI 响应超时，请重试。');
  String get aiProviderFailure => _t(
    'AI provider could not answer. Try again later.',
    'AI 服务暂时无法回答，请稍后再试。',
  );
  String get aiRequestUnsupported =>
      _t('This AI request is not supported yet.', '当前版本暂不支持这个 AI 请求。');
  String get aiNetworkFailure =>
      _t('Network failed. Your input was kept.', '网络连接失败，输入已保留。');
  String get aiChatNetworkFailure => _t(
    'Network failed. Your message was kept for retry.',
    '网络连接失败，消息已保留，可重试。',
  );
  String get aiUnknownFailure =>
      _t('AI request failed. Try again.', 'AI 请求失败，请重试。');
  String get authRequired => _t('Please sign in first.', '请先登录。');

  String get quickActions => _t('Quick Actions', '快捷操作');
  String get addFood => _t('Add Food', '添加食物');
  String get addWorkout => _t('Add Workout', '添加训练');
  String get saveWorkoutPlan => _t('Save Workout Record', '保存训练记录');

  String get estimateNotice => _t(
    'All values are estimates for personal logging. Energy ratio uses the deficit target plus logged net exercise; g/kg uses the bodyweight table independently.',
    '所有数值仅用于个人记录估算：热量赤字算法会加入已记录净运动消耗；g/kg 按体重查表独立计算。',
  );

  String get noFoodRecords => _t(
    'No food records yet. Tap Add Food to start logging.',
    '还没有食物记录，点击“添加食物”开始记录。',
  );

  String failedToLoadFood(Object error) =>
      _t('Failed to load food records: $error', '加载食物记录失败：$error');

  String get deleteRecord => _t('Delete Record', '删除记录');
  String get delete => _t('Delete', '删除');
  String get copy => _t('Copy', '复制');
  String get cancel => _t('Cancel', '取消');
  String get close => _t('Close', '关闭');
  String get retry => _t('Retry', '重试');
  String get date => _t('Date', '日期');
  String get change => _t('Change', '修改');

  String deleteFoodConfirm(String mealName, String date) =>
      _t('Delete "$mealName" on $date?', '确认删除 $date 的“$mealName”？');

  String get foodDeleted => _t('Food record deleted.', '食物记录已删除。');

  String failedToDeleteFood(Object error) =>
      _t('Failed to delete food record: $error', '删除食物记录失败：$error');

  String foodCopied(String mealName, String date) =>
      _t('"$mealName" copied to $date.', '已将 "$mealName" 复制到 $date。');

  String failedToCopyFood(Object error) =>
      _t('Failed to copy food record: $error', '复制食物记录失败: $error');

  String sourceLabel(String source) {
    switch (source) {
      case 'ai_paste':
        return _t('AI Paste', 'AI 粘贴');
      case 'ai_photo':
        return _t('AI Analysis', 'AI 分析');
      case 'manual':
        return _t('Manual', '手动录入');
      default:
        return source;
    }
  }

  String get recommendedGpt => _t('Recommended GPT', '推荐 GPT');

  String get recommendedGptHint {
    if (isChinese) {
      return '中文：打开 ${PromptTemplates.chineseGptName}\nEnglish: Open ${PromptTemplates.englishGptName}';
    }
    return 'Chinese: Open ${PromptTemplates.chineseGptName}\nEnglish: Open ${PromptTemplates.englishGptName}';
  }

  String get pasteAiResult => _t('Paste AI Result', '粘贴 AI 结果');
  String get pasteAiSubtitle =>
      _t('Paste external AI JSON and parse', '粘贴外部 AI JSON 并解析');
  String get manualEntry => _t('Manual Entry', '手动录入');
  String get manualEntrySubtitle =>
      _t('Manually input a food record', '手动填写一条食物记录');
  String get foodDetailTitle => _t('Food Detail', '食物详情');
  String get previewAiResultTitle => _t('Preview AI Result', 'AI 结果预览');
  String get foodMealNameLabel => _t('Meal name', '餐食名称');
  String get foodTotalWeightLabel => _t('Total weight', '总重量');
  String get foodCaloriesLabel => _t('Calories', '热量');
  String get foodProteinLabel => _t('Protein', '蛋白质');
  String get foodCarbsLabel => _t('Carbs', '碳水');
  String get foodFatLabel => _t('Fat', '脂肪');
  String get foodConfidenceLabel => _t('Confidence', '置信度');
  String get foodEstimationNotesLabel => _t('Estimation notes', '估算说明');
  String get foodNotesLabel => _t('Notes', '备注');
  String foodItemNameLabel(int index) => _t('Item $index name', '项目 $index 名称');
  String get unitGram => _t('g', 'g');
  String get unitKcal => _t('kcal', 'kcal');
  String get manualFoodRecordSaved =>
      _t('Manual food record saved.', '手动食物记录已保存。');
  String get foodRecordSaved => _t('Food record saved.', '食物记录已保存。');
  String get foodRecordUpdated => _t('Food record updated.', '食物记录已更新。');
  String failedToSaveFoodRecord(Object error) =>
      _t('Failed to save food record: $error', '保存食物记录失败：$error');
  String failedToSaveManualFoodRecord(Object error) =>
      _t('Failed to save manual record: $error', '保存手动食物记录失败：$error');
  String get foodRecordNotFound => _t('Record not found.', '未找到该记录。');
  String get noFoodItemRows =>
      _t('No item rows for this record.', '这条记录暂无 item 明细。');
  String get noFoodItemListDetected =>
      _t('No item list detected in JSON.', 'JSON 中未检测到 item 列表。');
  String get photoAiAnalysis => _t('AI Food Analysis', 'AI 食物分析');
  String get photoAiEntrySubtitle => _t(
    'Describe food or add photos to create an editable food draft',
    '描述食物或添加图片，生成可编辑食物草稿',
  );
  String get start => _t('Start', '开始');
  String get photoAiHeaderBody => _t(
    'FitLog AI estimates a draft from your description and up to 3 optional food images. Review and save on the next page.',
    'FitLog AI 会根据你的描述和最多 3 张可选食物图片估算草稿。请在下一页确认后再保存。',
  );
  String get photoAiPickPlaceholder =>
      _t('Add optional food photos', '可选添加食物图片');
  String get takePhoto => _t('Photo', '拍照');
  String get chooseFromGallery => _t('Gallery', '相册');
  String get retakePhoto => _t('Photo', '拍照');
  String get replacePhoto => _t('Replace', '换图');
  String get removePhoto => _t('Remove', '移除');
  String get photoAiNoteLabel => _t('Food description', '食物描述');
  String get photoAiNoteHint => _t(
    'Example: 100 g salmon; half the rice; skinless chicken thigh',
    '例如：100g 三文鱼；米饭只吃了一半；鸡腿去皮',
  );
  String get startPhotoAiAnalysis => _t('Analyze food', '开始分析');
  String get photoAiAnalyzing => _t('Analyzing...', '正在分析...');
  String get photoAiPickImageFirst =>
      _t('Describe the food or add at least one photo.', '请描述食物，或至少添加一张图片。');
  String get photoAiPickFailed =>
      _t('Could not open camera or gallery.', '无法打开相机或相册。');
  String get photoAiUnsupportedImage =>
      _t('Use a JPEG, PNG, or WebP image.', '请使用 JPEG、PNG 或 WebP 图片。');
  String get photoAiImageTooLarge => _t(
    'One compressed image is too large. Choose smaller images or retake it.',
    '有图片压缩后仍过大，请换更小的图片或重新拍摄。',
  );
  String get photoAiNeedsClarification => _t(
    'The food input is unclear. Add details or retake the photo.',
    '食物信息不够清楚，请补充说明或重新拍摄。',
  );
  String get photoAiNoDraft =>
      _t('AI did not return a usable food draft.', 'AI 未返回可用的食物草稿。');
  String get photoAiNetworkFailure => _t(
    'Network failed. Your input is still here. Try again.',
    '网络连接失败，当前输入仍在，可重试。',
  );
  String get comingSoon => _t('Coming soon', '即将上线');

  String get pasteInstruction => _t(
    'Paste the JSON output from ChatGPT or Gemini:',
    '粘贴来自 ChatGPT 或 Gemini 的 JSON 输出：',
  );

  String get parse => _t('Parse', '解析');
  String get parsing => _t('Parsing...', '解析中...');

  String get pleasePasteJson => _t('Please paste JSON first.', '请先粘贴 JSON 内容。');

  String parseError(String message) =>
      _t('Unable to parse JSON: $message', 'JSON 解析失败：$message');

  String get parseErrorGeneric =>
      _t('Unable to parse JSON. Please check the format.', '无法解析 JSON，请检查格式。');

  String get bodyProfileGoal => _t('Body Profile & Goal', '身体资料与目标');
  String get ageLabel => _t('Age', '年龄');
  String get heightCmLabel => _t('Height (cm)', '身高 (cm)');
  String get weightKgLabel => _t('Weight (kg)', '体重 (kg)');
  String get bodyFatPercentLabel => _t('Body Fat (%)', '体脂 (%)');
  String get waistCmLabel => _t('Waist (cm)', '腰围 (cm)');
  String get sexForFormulaLabel => _t('Sex', '性别');
  String get bodyTrendsTitle => _t('Body Trends', '身体趋势');
  String get bodyTrendWeightLabel => _t('Weight', '体重');
  String get bodyTrendFatLabel => _t('Fat %', '体脂');
  String get bodyTrendWaistLabel => _t('Waist', '腰围');
  String bodyTrendRangeLabel(int days) => _t('${days}D', '$days天');
  String bodyTrendChangeLabel(int days) => _t('${days}D change', '$days天变化');
  String bodyTrendLogCount(int count, int days) =>
      _t('Logs $count/$days', '记录 $count/$days');
  String get bodyTrendNoRecords => _t('No records yet', '暂无记录');
  String get bodyTrendNeedTwoRecords =>
      _t('Add 2 records to show a trend', '记录满 2 次后显示趋势');
  String get bodyTrendNotEnoughRecords =>
      _t('Not enough records in this range', '当前周期记录不足');
  String get bodyMetricDraftBlocked => _t(
    'Save or discard current Profile changes before editing past body records.',
    '请先保存或放弃当前资料修改，再编辑过往身体记录。',
  );
  String get bodyMetricPastDateRequired =>
      _t('Select a past date.', '请选择过去日期。');
  String get bodyMetricRecordSaved => _t('Body record saved.', '身体记录已保存。');
  String get bodyMetricRecordDeleted => _t('Body record deleted.', '身体记录已删除。');
  String bodyMetricDeleteConfirmTitle(String date) =>
      _t('Delete body record for $date?', '删除 $date 的身体记录？');
  String get bodyMetricDeleteConfirmBody => _t(
    'This removes the historical weight, body-fat, and waist record for that date. Body Trends, calibration, and reviews that use weight history may change after refresh.',
    '这会删除该日期的历史体重、体脂和腰围记录。刷新后，身体趋势、校准和使用体重历史的 review 结果可能变化。',
  );
  String get bodyMetricDiscardTitle =>
      _t('Discard body record edits?', '放弃身体记录修改？');
  String get bodyMetricDiscardMessage => _t(
    'Switching dates will remove the unsaved body record edits.',
    '切换日期会放弃当前未保存的身体记录修改。',
  );
  String get bodyMetricDiscardAction => _t('Discard Edits', '放弃修改');
  String get activityLevelLabel => _t('Activity Level', '活动水平');
  String get goalPhaseLabel => _t('Goal phase', '目标阶段');
  String get cuttingLabel => _t('Cutting', '减脂期');
  String get bulkingLabel => _t('Bulking', '增肌期');
  String get dietPlanStrategyLabel => _t('Diet strategy', '饮食计划策略');
  String get strategyNoneLabel => _t('N/A', '不使用');
  String get carbCyclingLabel => _t('Carb cycle', '碳循环');
  String get carbTaperingLabel => _t('Carb Taper', '碳水渐降');
  String get cuttingOnlyStrategyNotice => _t(
    'This release supports carb cycling and carb tapering only in the cutting phase.',
    '本轮仅在减脂期支持碳循环和碳水渐降。',
  );
  String get minorStrategyBlockedNotice => _t(
    'For users under 18, cutting strategies are disabled and only general logging is available.',
    '未满 18 岁时会禁用减脂策略，仅保留普通记录功能。',
  );
  String get carbCyclingIntro => _t(
    'Carb cycling redistributes weekly carbs across high, medium, and low days. It does not guarantee fat loss.',
    '碳循环只是把一周碳水重新分配到高、中、低日，不保证自动减脂。',
  );
  String get carbTaperingIntro => _t(
    'Carb tapering reviews weight trend, food coverage, and training stability locally. Suggestions never apply automatically.',
    '碳水渐降会在本地检查体重趋势、饮食覆盖率和训练稳定性，建议不会自动应用。',
  );
  String homeCarbCyclingSummary(String modeLabel) => _t(
    'Redistributes carbs across high, medium, and low days after the base target is calculated. Your base method is still $modeLabel.',
    '在基础目标算出后，把碳水分配到高、中、低日。当前的基础算法仍然是 $modeLabel。',
  );
  String homeCarbTaperingSummary(String modeLabel) => _t(
    'Reviews weight trend, food coverage, and training stability locally, then suggests small carb changes for you to confirm. Your base method is still $modeLabel.',
    '在本地复盘体重趋势、饮食覆盖率和训练稳定性后，再给出小步碳水调整建议，由你确认。当前的基础算法仍然是 $modeLabel。',
  );
  String strategyGuideTitle(String strategyLabel) =>
      _t('$strategyLabel guide', '$strategyLabel 说明');
  String get strategyGuideBaseMethodTitle =>
      _t('Base method relationship', '和基础算法的关系');
  String get strategyGuideCorePrincipleTitle => _t('Core principle', '核心原理');
  String get strategyGuideNumbersTitle =>
      _t('How the numbers change', '数值怎么变化');
  String get strategyGuideSetupTitle => _t('How to set it up', '怎么设置更稳妥');
  String get strategyGuideKnowTitle =>
      _t('What to know before using it', '使用前要知道');
  String strategyGuideBaseMethodBody(String modeLabel) => _t(
    'This strategy does not replace your base diet method. It is layered on top of $modeLabel after the base target is calculated.',
    '这个策略不会替代你的基础饮食算法。它是在基础目标先算出来之后，再叠加在 $modeLabel 之上的一层策略。',
  );
  List<String> carbCyclingGuidePrinciple() => <String>[
    _t(
      'Carb cycling is not a second diet formula. FitLog first calculates your base target, then redistributes only the carbohydrate portion across the week.',
      '碳循环不是第二套饮食算法。FitLog 会先算出你的基础目标，再只对其中的碳水部分做一周内的重新分配。',
    ),
    _t(
      'Protein and fat stay comparatively stable. The main thing that moves is carbs, so the strategy changes fuel timing more than it changes the whole plan.',
      '蛋白质和脂肪会相对稳定，主要移动的是碳水，所以它更像是在调配供能时机，而不是把整套计划推翻重来。',
    ),
    _t(
      'The week is normalized before the daily target is shown, so a high-carb day is offset by lower-carb days elsewhere instead of silently adding extra weekly carbs.',
      '系统会先对整周做归一化，再给出当天目标，所以高碳日会由别的日子的较低碳水来平衡，而不是悄悄把整周碳水总量抬高。',
    ),
  ];
  List<String> carbCyclingGuideNumbers({
    required double highMultiplier,
    required double mediumMultiplier,
    required double lowMultiplier,
    required double minimumCarbsG,
  }) => <String>[
    _t(
      'Your current weekly multipliers are high x${highMultiplier.toStringAsFixed(2)}, medium x${mediumMultiplier.toStringAsFixed(2)}, and low x${lowMultiplier.toStringAsFixed(2)} before normalization.',
      '你当前的一周倍率在归一化前分别是：高碳 x${highMultiplier.toStringAsFixed(2)}、中碳 x${mediumMultiplier.toStringAsFixed(2)}、低碳 x${lowMultiplier.toStringAsFixed(2)}。',
    ),
    _t(
      'High, medium, and low days all start from the same base carbs. FitLog then shifts that base up or down, while keeping protein and fat steady.',
      '高碳、中碳、低碳都从同一个基础碳水出发，FitLog 只是在这个基础上把当天碳水往上或往下拨动，蛋白质和脂肪保持稳定。',
    ),
    _t(
      'A carb floor is always active. If the low day would fall below about ${minimumCarbsG.toStringAsFixed(0)} g, FitLog clamps it instead of pushing lower.',
      '系统始终会保留碳水下限。如果低碳日会低于约 ${minimumCarbsG.toStringAsFixed(0)} g，FitLog 会直接限住，不再继续往下压。',
    ),
  ];
  List<String> carbCyclingGuideSetup() => <String>[
    _t(
      'Start by marking your hardest or longest training days as high carb, your normal training days as medium carb, and rest or easy days as low carb.',
      '最稳妥的起点是：把最重或时间最长的训练日设成高碳，把普通训练日设成中碳，把休息日或很轻松的活动日设成低碳。',
    ),
    _t(
      'If you only have one or two genuinely hard sessions each week, keep the rest as medium or low instead of making every training day high carb.',
      '如果你一周里真正很重的训练只有一到两天，就把那几天设成高碳，其余训练日尽量放在中碳或低碳，不要把所有训练日都设成高碳。',
    ),
    _t(
      'If recovery, appetite, or adherence gets worse, move one day back toward medium before you raise the multipliers further.',
      '如果恢复、食欲控制或执行稳定性开始变差，优先把某一天调回中碳，而不是继续把倍率拉得更高。',
    ),
  ];
  List<String> carbCyclingGuideKnow() => <String>[
    _t(
      'Carb cycling is not a magic fat-loss switch. Weekly intake and consistency still matter most.',
      '碳循环不是自动减脂开关，整周总摄入和执行稳定性仍然最重要。',
    ),
    _t(
      'FitLog keeps a carb safety floor and will clamp targets that drop too low.',
      'FitLog 会保留碳水安全下限，过低时会直接限制目标。',
    ),
    _t(
      'If you use g/kg, the strategy still sits on top of your macro-first target. If you use energy ratio, it sits on top of your kcal-first target.',
      '如果你用 g/kg，它叠加在宏量优先目标上；如果你用能量比例法，它叠加在 kcal 优先目标上。',
    ),
  ];
  List<String> carbTaperingGuidePrinciple() => <String>[
    _t(
      'Carb tapering is a local review loop for cutting. It does not replace your base diet mode, and it never applies changes automatically.',
      '碳水渐降是减脂期里的本地复盘回路。它不会替代你的基础饮食模式，也不会自动替你改计划。',
    ),
    _t(
      'FitLog looks at a rolling weight trend, food-log coverage, and training stability together so it does not overreact to one noisy weigh-in.',
      'FitLog 会把滚动体重趋势、饮食记录覆盖率和训练稳定性一起看，避免因为一次噪音很大的称重就做出激进反应。',
    ),
    _t(
      'The output is only a suggestion such as keep, decrease carbs, pause taper, or no data. You still decide whether to apply it.',
      '最终输出也只是建议，比如保持、降低碳水、暂停渐降或数据不足，是否应用仍然由你决定。',
    ),
  ];
  List<String> carbTaperingGuideNumbers({
    required int reviewDays,
    required double targetLossPctPerWeek,
    required double stepG,
    required double conservativeMaxStepG,
    required double minimumCarbsG,
  }) => <String>[
    _t(
      'Your current review period is $reviewDays days. A longer window is steadier but slower; a shorter window reacts faster but is easier to misread.',
      '你当前的复盘周期是 $reviewDays 天。周期越长，判断越稳；周期越短，反应越快，但也越容易被噪音带偏。',
    ),
    _t(
      'Your current target loss rate is ${targetLossPctPerWeek.toStringAsFixed(2)}% per week. FitLog compares the rolling trend with that setting, then checks whether the difference is large enough to justify action.',
      '你当前的目标减重速度是每周 ${targetLossPctPerWeek.toStringAsFixed(2)}%。FitLog 会先把滚动趋势和这个设定比较，再判断偏差是否大到值得调整。',
    ),
    _t(
      'Your selected taper step is ${stepG.toStringAsFixed(0)} g, and the app keeps the effective step conservative by capping it at about ${conservativeMaxStepG.toStringAsFixed(0)} g for your current body weight.',
      '你当前选择的渐降步长是 ${stepG.toStringAsFixed(0)} g；同时系统还会按你现在的体重把有效步长保守地限制在约 ${conservativeMaxStepG.toStringAsFixed(0)} g 以内。',
    ),
    _t(
      'If the projected carbs would fall below about ${minimumCarbsG.toStringAsFixed(0)} g per day, FitLog blocks the decrease instead of chasing scale speed.',
      '如果预计碳水会掉到每天约 ${minimumCarbsG.toStringAsFixed(0)} g 以下，FitLog 会阻止继续下降，而不是为了追体重速度硬压。',
    ),
  ];
  List<String> carbTaperingGuideSetup() => <String>[
    _t(
      'A good default target-loss setting is around 0.5% of body weight per week. Move toward the high end only when recovery, food logging, and training stability are all solid.',
      '比较稳妥的默认目标减重速度通常是每周体重的 0.5% 左右。只有在恢复、饮食记录和训练稳定性都不错时，才考虑往更激进的高端去调。',
    ),
    _t(
      'Use smaller taper steps such as 5-10 g when your logging is patchy, your carbs are already low, or you are close to the carb floor. Use 10-15 g when the trend is clearly too slow and the data quality is good.',
      '如果你的记录不够完整、当前碳水本来就不高，或者已经接近碳水下限，更适合用 5 到 10 g 这种小步长。只有当趋势明显太慢、而且数据质量不错时，再考虑 10 到 15 g 的步长。',
    ),
    _t(
      'Use a longer review period such as 21-28 days when your body weight swings a lot. Use 7 days only when weighing and food logging are both very consistent.',
      '如果你的体重日波动比较大，优先用 21 到 28 天这种更长的复盘周期。只有在称重和饮食记录都非常稳定时，才建议把周期缩到 7 天。',
    ),
  ];
  List<String> carbTaperingGuideKnow() => <String>[
    _t(
      'Weak data should lead to no suggestion, not fake confidence.',
      '当数据不够时，正确结果应该是不给建议，而不是装作很确定。',
    ),
    _t(
      'If loss is already too fast, the app may suggest pausing the taper instead of cutting carbs further.',
      '如果减重已经太快，App 可能会建议暂停渐降，而不是继续往下砍碳水。',
    ),
    _t(
      'This strategy still respects the carb safety floor and the current base diet mode.',
      '这个策略仍然会尊重碳水安全下限，也不会绕开你当前的基础饮食算法。',
    ),
  ];
  String get weeklyCarbPatternLabel => _t('Weekly carb pattern', '每周碳水模式');
  String get carbCyclePreviewLabel => _t('Current week preview', '本周预览');
  String get carbCycleMultiplierLabel => _t('Multiplier preview', '倍率预览');
  String get carbTaperReviewTitle => _t('Carb Taper Review', '碳水渐降复核');
  String get carbTaperCurrentOffsetLabel => _t('Current carb offset', '当前碳水偏移');
  String get carbTaperReviewPeriodLabel => _t('Review period', '复核周期');
  String get carbTaperTargetLossLabel => _t('Target loss rate', '目标减重速度');
  String get carbTaperStepLabel => _t('Taper step', '每次渐降步长');
  String get carbTaperApplyLabel => _t('Apply', '应用');
  String get dismissLabel => _t('Dismiss', '忽略');
  String get strategyBadgeLabel => _t('Strategy', '策略');
  String get todayCarbDayTypeLabel => _t('Today carb day', '今日碳日类型');
  String get carbAdjustmentLabel => _t('Carb adjustment', '碳水调整');
  String get currentTaperLabel => _t('Current taper', '当前渐降');
  String get pendingReviewHint => _t(
    'A carb taper review is waiting in Profile.',
    'Profile 中有一条待处理的碳水渐降复核。',
  );
  String get strategyDisabledForBulking => _t(
    'Diet plan strategy is hidden in bulking for this release.',
    '本轮增肌期暂不开放饮食计划策略。',
  );
  String get dailyGoalTypeLabel => _t('Daily Goal Type', '每日目标类型');
  String dailyGoalKcalLabelForPhase(String phase) => phase == 'bulking'
      ? _t('Daily Calorie Surplus (kcal)', '每日热量盈余 (kcal)')
      : _t('Daily Calorie Deficit (kcal)', '每日热量赤字 (kcal)');
  String get dailyGoalKcalLabel => dailyGoalKcalLabelForPhase('cutting');
  String get dietCalculationModeLabel =>
      _t('Diet calculation method', '饮食计算方法');
  String get energyRatioModeLabel => _t('Energy ratio', '热量比例算法');
  String get gramPerKgModeLabel => _t('g/kg method', 'g/kg 体重算法');
  String get trainingFrequencyPerWeekLabel =>
      _t('Training Frequency / Week', '每周训练频率');
  String trainingFrequencyOptionLabel(int value) =>
      _t('$value sessions/week', '每周 $value 次');
  String get macroSelfCheckPeriodLabel => _t('Self-check Period', '自检周期');
  String macroSelfCheckPeriodOptionLabel(int value) =>
      _t('${value}d', '$value 天');
  String get macroSelfCheckEnabledLabel =>
      _t('History-based suggestions', '启用历史训练记录自检建议');
  String get macroSelfCheckTitle => _t('Training Freq Check', '训练频率自检');
  String get applySuggestion => _t('Apply', '应用建议');
  String get keepCurrentSetting => _t('Keep Current', '保持当前设置');
  String get macroSelfCheckNoData =>
      _t('No valid training days in selected period yet.', '所选周期内暂无有效训练日。');
  String get macroSelfCheckConsistent =>
      _t('Your setting matches recent training.', '当前设置与历史训练记录基本一致。');
  String get macroSelfCheckReminderCooldownHint => _t(
    'A recommendation exists but reminder cooldown is active. You can adjust it manually below.',
    '当前存在推荐档位，但提醒冷却中。你可以在下方手动调整。',
  );
  String macroSelfCheckCurrentFrequencyText(int value) =>
      _t('Current: $value times/week', '当前设置：每周训练 $value 次');
  String macroSelfCheckActiveDaysText(int periodDays, int activeDays) => _t(
    'Past $periodDays days: trained on $activeDays days',
    '过去 $periodDays 天：实际训练 $activeDays 天',
  );
  String macroSelfCheckAverageFrequencyText(double weeklyFrequency) => _t(
    'Logged: ~${weeklyFrequency.toStringAsFixed(1)} sessions/week',
    '记录折算频率：约每周 ${weeklyFrequency.toStringAsFixed(1)} 次',
  );
  String macroSelfCheckRecommendedText(int value) =>
      _t('Suggested: $value times/week', '建议设置为：每周训练 $value 次');
  String get macroSelfCheckBelowRangeNotice => _t(
    'Recent logged frequency is below the shared training-frequency range. FitLog keeps the 2 sessions/week tier as the minimum default.',
    '最近记录频率低于共享训练频率范围，FitLog 会把每周 2 次作为最低默认档位。',
  );
  String get macroRatioSettingsLabel =>
      _t('Daily Macro Ratio (%)', '每日三大营养比例 (%)');
  String get bulkingMacroRatioSuggestion => _t(
    'Default bulking suggestion: protein 25%, carbs 50%, fat 25%.',
    '增肌期默认比例建议：protein 25%, carbs 50%, fat 25%。',
  );
  String get proteinRatioPercentLabel => _t('Protein Ratio (%)', '蛋白质比例 (%)');
  String get carbsRatioPercentLabel => _t('Carbs Ratio (%)', '碳水比例 (%)');
  String get fatRatioPercentLabel => _t('Fat Ratio (%)', '脂肪比例 (%)');
  String get macroRatioHint =>
      _t('Protein + Carbs + Fat should equal 100%.', '蛋白质 + 碳水 + 脂肪 应等于 100%。');
  String get macroRatioTotalInvalid =>
      _t('Macro ratio total must be 100.', '三大营养比例总和必须为 100。');
  String get enterValidMacroRatio =>
      _t('Enter a valid ratio between 0 and 100.', '请输入 0 到 100 的有效比例。');
  String get dateLabel => _t('Date', '日期');
  String get notesLabel => _t('Notes', '备注');
  String get durationMinutesLabel => _t('Duration (minutes)', '时长 (分钟)');
  String get bodyWeightKgLabel => _t('Body Weight (kg)', '体重 (kg)');
  String get intensityLabelText => _t('Intensity', '强度');
  String get estimatedCaloriesLabel => _t('Estimated Calories', '估算消耗');
  String get estimatedTotalCaloriesLabel =>
      _t('Estimated Total Calories', '计划总估算消耗');
  String get calculatedReference => _t('Calculated Reference', '计算参考');
  String get exportData => _t('Export & Data', '导出与数据');
  String get exportXlsx => _t('Export XLSX', '导出 XLSX');
  String get exportCsv => _t('Export CSV', '导出 CSV');
  String exportReady(String type, String filePath) =>
      _t('$type export ready: $filePath', '$type 已导出：$filePath');
  String exportFailed(String type, Object error) =>
      _t('$type export failed: $error', '$type 导出失败：$error');
  String get clearAllData => _t('Clear All Local Data', '清空本地数据');
  String get accountActionsTitle => _t('Account', '账号');
  String get signOutAccount => _t('Sign out', '退出账号');
  String get signOutAccountTitle => _t('Sign out of this account?', '退出当前账号？');
  String get signOutAccountBody => _t(
    'Cloud official records stay in this account. This device will clear the sign-in session and Cloud Profile cache.',
    '云端正式记录仍保留在当前账号中；这台设备会清除登录态和 Cloud Profile 缓存。',
  );
  String get signedOut => _t('Signed out.', '已退出账号。');

  String get languageSettings => _t('Language', '语言设置');
  String get english => 'English';
  String get chinese => '中文';
  String get themeSettings => _t('Theme', '主题');
  String get greenTheme => _t('Green', '绿色');
  String get blackTheme => _t('Black', '黑橙');

  String get clearAllDataTitle => _t('Clear All Local Data', '清空本地数据');
  String get clearAllDataBody => _t(
    'This will permanently remove all local food, workout, and profile data. Continue?',
    '这会永久删除本地所有饮食、训练和资料数据。是否继续？',
  );

  String get clearData => _t('Clear Data', '清空数据');

  String get profileSaved => _t('Profile saved.', '资料已保存。');
  String get allDataCleared => _t('All local data cleared.', '本地数据已清空。');

  String get ageMinorNoDeficit => _t(
    'Age under 18 cannot use deficit target. Switched to maintenance.',
    '18 岁以下不支持赤字目标，已切换为维持。',
  );
  String get ageMinorNoCuttingStrategy => _t(
    'Age under 18 cannot use cutting carb strategies. Strategy reset to None.',
    '18 岁以下不能启用减脂碳策略，已重置为不使用。',
  );

  String get aggressiveGoalWarning => _t(
    'This deficit may be too aggressive. Prioritize long-term health.',
    '该目标可能比较激进，建议以健康和长期可持续为主。',
  );

  String get minorReminder => _t(
    'For users under 18, no weight-loss recommendation is shown.',
    '年龄小于 18 岁时不提供减重建议，仅记录与展示数据。',
  );

  String get saveProfile => _t('Save Profile', '保存资料');
  String get saveChanges => _t('Save Changes', '保存修改');
  String get save => _t('Save', '保存');
  String get done => _t('Done', '完成');
  String get modified => _t('Modified', '已修改');
  String get discardChanges => _t('Discard', '放弃');
  String get saveProfileChanges => _t('Save Changes', '保存更改');
  String profileUnsavedCount(int count) => _t('$count unsaved', '$count 项未保存');
  String get maintenance => _t('Maintenance', '维持');
  String get deficit => _t('Deficit', '赤字');
  String get surplus => _t('Surplus', '盈余');
  String get male => _t('Male', '男');
  String get female => _t('Female', '女');
  String get preferNot => _t('Prefer not to say', '不透露');
  String get sedentary => _t('Sedentary', '久坐');
  String get lightlyActive => _t('Lightly Active', '轻度活跃');
  String get moderatelyActive => _t('Moderately Active', '中度活跃');
  String get veryActive => _t('Very Active', '高度活跃');
  String get enterValidAge => _t('Enter valid age', '请输入有效年龄');
  String get enterValidHeight => _t('Enter valid height', '请输入有效身高');
  String get enterValidWeight => _t('Enter valid weight', '请输入有效体重');
  String get enterValidBodyFat => _t('Enter valid body fat', '请输入有效体脂');
  String get enterValidWaist => _t('Enter valid waist', '请输入有效腰围');

  String get noWorkoutRecords => _t(
    'No workout sessions yet. Tap Add Workout to begin.',
    '还没有训练记录，点击“添加训练”开始。',
  );

  String failedToLoadWorkout(Object error) =>
      _t('Failed to load workout records: $error', '加载训练记录失败：$error');

  String get workoutDeleted => _t('Workout deleted.', '训练记录已删除。');

  String failedToDeleteWorkout(Object error) =>
      _t('Failed to delete workout: $error', '删除训练记录失败：$error');

  String get workoutPlan => _t('Workout Record', '训练记录');
  String get workoutPlanList => _t('Workout Records', '训练记录');
  String get startTimeLabel => _t('Start time', '开始时间');
  String get totalDurationLabel => _t('Total duration', '总时长');
  String get exerciseNamesLabel => _t('Exercises', '记录动作');
  String get actionsInPlan => _t('Exercises in this record', '本记录动作');
  String get noActionsInPlan => _t('No exercises in this record.', '该记录暂无动作。');

  String deleteWorkoutConfirm(String exerciseName, String date) =>
      _t('Delete $exerciseName on $date?', '确认删除 $date 的“$exerciseName”？');

  String deleteWorkoutPlanConfirm(int count, String date) => _t(
    'Delete this workout record on $date? ($count exercises)',
    '确认删除 $date 这条训练记录？（共 $count 个动作）',
  );

  String get unsavedWorkoutDraftTitle => _t('Unsaved workout draft', '未保存训练');
  String get workoutDraftLabel => _t('Workout draft', '训练草稿');
  String workoutDraftCountSummary(int count) =>
      _t('$count exercise${count == 1 ? '' : 's'}', '$count 个动作');
  String workoutDraftBodyPartSummary(String bodyParts, int count) => _t(
    '$bodyParts · $count exercise${count == 1 ? '' : 's'}',
    '$bodyParts · $count 个动作',
  );
  String get workoutDraftUntitled => _t('Tap to continue editing', '点击继续编辑');
  String get workoutDraftExistsTitle =>
      _t('Continue the existing draft?', '继续未保存训练？');
  String get workoutDraftExistsMessage => _t(
    'You already have an unsaved workout draft. Continue it, or discard it and start a new record.',
    '当前已有一条未保存训练草稿。你可以继续编辑，或者先舍弃它再开始新的记录。',
  );
  String get workoutEditDraftConflictMessage => _t(
    'You already have another unsaved workout draft. Continue it, or discard it before editing this saved record.',
    '当前还有另一条未保存训练草稿。你可以继续编辑那条草稿，或者先舍弃它再编辑这条已保存记录。',
  );
  String get continueEditing => _t('Continue Editing', '继续编辑');
  String get discardAndStartNewWorkout => _t('Discard And Start New', '舍弃并新建');
  String get discardAndEditWorkout =>
      _t('Discard And Edit This Record', '舍弃并编辑这条记录');
  String get discardWorkoutDraftTitle =>
      _t('Discard this workout draft?', '舍弃这次训练？');
  String get discardWorkoutDraftMessage => _t(
    'Discarding will delete this unsaved workout draft.',
    '舍弃后，这次未保存的训练草稿会被删除。',
  );
  String get discardWorkoutDraftAction => _t('Discard This Workout', '舍弃本次训练');
  String get discardWorkoutChangesTitle =>
      _t('Discard these workout changes?', '放弃本次修改？');
  String get discardWorkoutChangesMessage => _t(
    'Discarding will remove your unsaved workout changes. The saved workout record will stay as it is.',
    '放弃后，当前未保存的训练修改会被删除，已保存的训练记录保持不变。',
  );
  String get discardWorkoutChangesAction =>
      _t('Discard These Changes', '放弃本次修改');
  String get searchExercise => _t('Search exercise', '搜索动作');
  String get exercisesLibrary => _t('Exercise Library', '动作库');
  String get allBodyParts => _t('All muscle groups', '所有肌群');
  String get selectedExercise => _t('Selected Exercise', '已选动作');
  String get selectedExercises => _t('Selected Exercises', '已选动作计划');
  String selectedExercisesCount(int count) =>
      _t('$count selected', '已选 $count 个');
  String addExercisesWithCount(int count) =>
      _t('Add selected exercises ($count)', '添加已选动作（$count）');
  String get addExercises => _t('Add', '添加运动');
  String get exercisePlanDetails => _t('Exercise Record Details', '动作记录详情');
  String get exercisePickerCollapsedHint => _t(
    'Exercise library is hidden by default. Tap the button to select multiple exercises.',
    '动作库默认折叠，点击按钮后可进入动作库一次多选。',
  );
  String get noExerciseSelectedYet =>
      _t('No exercise selected yet.', '还没有选择动作。');
  String get tapAddExerciseToBuildPlan => _t(
    'Tap Add to build your workout record first.',
    '先点击“添加运动”，再填写每个动作的详细信息。',
  );
  String get tapExerciseToBuildPlan => _t(
    'Tap exercises above to build a multi-exercise workout record.',
    '在上方点选动作，即可建立一个包含多个动作的训练记录。',
  );
  String get workoutDetails => _t('Workout Details', '训练参数');
  String get setsPlan => _t('Sets', '组数');
  String setLabel(int index) => _t('Set #$index', '第 $index 组');
  String get weightKgShortLabel => _t('Weight (kg)', '重量 (kg)');
  String get perSideWeightKgShortLabel => _t('Per-side (kg)', '每侧重量 (kg)');
  String get addedWeightKgShortLabel => _t('Added (kg)', '加重 (kg)');
  String get assistWeightKgShortLabel => _t('Assist (kg)', '辅助 (kg)');
  String get repsLabel => _t('Reps', '次数');
  String get perSideRepsLabel => _t('Per-side reps', '每侧次数');
  String get setDurationLabel => _t('Set duration', '单组时长');
  String get activeDurationLabel =>
      _t('Active duration (minutes)', '实际运动时长 (分钟)');
  String get activeDurationHelperText => _t(
    'For interval work, enter active movement time only, excluding rest.',
    '间歇训练只填写实际运动时间，不包含休息。',
  );
  String get cardioIntensityFieldLabel => _t('Session intensity', '本次强度');
  String get cardioIntensityQuestion => _t(
    'At this pace, about how long could you keep going continuously?',
    '保持这次的速度 / 节奏，你大概能连续维持多久？',
  );
  String get customExercise => _t('Custom', '自定义动作');
  String get addExercise => _t('Add exercise', '添加动作');
  String get strengthExercise => _t('Strength', '力量');
  String get cardioExercise => _t('Cardio', '有氧');
  String get exerciseNameLabel => _t('Exercise name', '动作名');
  String get exerciseNameRequired =>
      _t('Please enter an exercise name.', '请输入动作名。');
  String get primaryBodyPart => _t('Primary body part', '主要部位');
  String get secondaryBodyPartOptional =>
      _t('Secondary body part (optional)', '副部位（可选）');
  String get noneOption => _t('None', '无');
  String get exerciseStructureLabel => _t('Exercise structure', '动作结构');
  String get loadInputMode => _t('Weight entry', '重量填写方式');
  String get repsInputMode => _t('Rep entry', '次数填写方式');
  String get setEntryMode => _t('Set entry', '组内填写方式');
  String get customCardioDefinitionHint => _t(
    'Cardio custom exercises use duration and session intensity. Weight, reps, sets, and body-part fields are not used.',
    '自定义有氧只使用时长和本次强度；不填写重量、次数、组数和部位。',
  );
  String get saveCustomExercisesTitle =>
      _t('Save custom exercises?', '保存自定义动作？');
  String saveCustomExercisesMessage(int count) => _t(
    'Save $count temporary custom exercise${count == 1 ? '' : 's'} to the reusable library?',
    '是否将 $count 个临时自定义动作保存到可复用动作库？',
  );
  String get notNow => _t('Not now', '暂不');
  String get addSet => _t('Add Set', '新增组');
  String get removeExercise => _t('Remove exercise', '移除动作');
  String get removeSet => _t('Remove set', '移除组');
  String get bodyweightAddedLoadHint => _t(
    'For bodyweight exercises, weight means added load. Enter 0 for bodyweight only.',
    '自重动作中“重量”表示额外加重；填 0 表示仅自重。',
  );
  String get bodyweightAssistLoadHint => _t(
    'For assisted movements, weight means assistance load. Actual load = bodyweight - assistance.',
    '辅助动作中“重量”表示辅助重量；计算时实际负重 = 体重 - 辅助重量。',
  );
  String get completeBeforeSaveHint => _t(
    'Mark completed sets before saving. Unchecked sets will not be saved.',
    '保存前请勾选已完成组，未勾选的组不会被保存。',
  );
  String get cardioNoSetPlan =>
      _t('Cardio does not require set planning.', '有氧训练不需要设置组数。');
  String get cardioDurationHint => _t(
    'Cardio calories are calculated from duration and body weight. Set this movement duration separately.',
    '有氧消耗按时长和体重计算，请为每个有氧动作单独填写时长。',
  );
  String get strengthDurationNotice => _t(
    'Note: Strength calories here are net exercise calories. Inter-set rest baseline is not added. Long rest does not linearly increase calories.',
    '注意：力量训练这里按净额外消耗估算，不叠加组间静息基础消耗。长时间休息不会线性增加消耗。',
  );
  String usingProfileWeight(double weightKg) => _t(
    'Using profile weight: ${weightKg.toStringAsFixed(1)} kg',
    '使用资料体重：${weightKg.toStringAsFixed(1)} kg',
  );
  String get durationSplitHint => _t(
    'Duration will be distributed across selected exercises.',
    '总时长会分配到已选动作中用于估算。',
  );
  String get saveWorkout => _t('Save Workout', '保存训练');
  String workoutPlanSavedCount(int count) => _t(
    'Saved $count exercises in this workout record.',
    '已保存本次训练记录中的 $count 个动作。',
  );
  String workoutRecordSavedCount(int count) => _t(
    'Saved $count exercises in this workout record.',
    '已保存本次训练记录中的 $count 个动作。',
  );
  String get workoutSaved => _t('Workout session saved.', '训练记录已保存。');
  String get editWorkoutRecord => _t('Edit Workout Record', '编辑训练记录');
  String get workoutRecordDetails => _t('Workout Record Details', '训练记录详情');
  String get workoutRecordMeta => _t('Training Parameters', '训练参数');
  String get workoutRecordNameLabel => _t('Record Name', '训练记录名称');
  String get workoutRecordNameHint =>
      _t('Example: Cycle 3 Week 4 Chest / Shoulder B', '例如：循环3 周4 胸肩二');
  String get workoutRecordNameRequired =>
      _t('Please enter a workout record name.', '请输入训练记录名称。');
  String get noCompletedSetsToSave =>
      _t('Please complete at least one set before saving.', '请至少完成一组后再保存。');
  String get totalVolumeLabel => _t('Volume', '运动量');
  String get totalSetsLabel => _t('Sets', '组数');
  String get chooseExercise => _t('Please choose an exercise.', '请选择一个动作。');
  String get chooseAtLeastOneExercise =>
      _t('Please select at least one exercise.', '请至少选择一个动作。');
  String get invalidDuration =>
      _t('Duration must be greater than 0.', '训练时长必须大于 0。');
  String invalidDurationForExercise(String exerciseName) => _t(
    'Please set duration > 0 for $exerciseName.',
    '请为“$exerciseName”填写大于 0 的时长。',
  );
  String invalidSetValue(String exerciseName) => _t(
    'Please check set values for $exerciseName.',
    '请检查“$exerciseName”的组数参数。',
  );
  String invalidActiveDurationForExercise(String exerciseName) => _t(
    'Please set active duration for $exerciseName, and keep it within total duration.',
    '请为“$exerciseName”填写实际运动时长，且不要超过总时长。',
  );
  String noSetsForExercise(String exerciseName) => _t(
    'Please add at least one set for $exerciseName.',
    '请至少为“$exerciseName”添加一组。',
  );

  String get completeSet => _t('Complete Set', '完成本组');
  String get completed => _t('Completed', '已完成');
  String get workoutDraftNotificationCompleteTitle =>
      _t('Sets complete', '训练组已完成');
  String get workoutDraftNotificationCompleteBody =>
      _t('Return to save workout', '返回保存训练');
  String get workoutDraftNotificationContinueBody =>
      _t('Return to continue workout', '返回继续训练');
  String workoutDraftNotificationSetBody(
    int setNumber,
    int totalSets,
    String performance,
  ) => _t(
    'Set $setNumber of $totalSets - $performance',
    '第 $setNumber 组，共 $totalSets 组 - $performance',
  );
  String workoutDraftNotificationSetPerformance(String weight, String reps) =>
      _t('$weight kg x $reps reps', '$weight kg x $reps 次');
  String workoutDraftNotificationSetDurationPerformance(
    String weight,
    String duration,
  ) => _t('$weight kg x $duration', '$weight kg x $duration');

  String get todayFoodList => _t('Today Food Records', '今日食物记录');
  String get todayWorkoutList => _t('Today Workout Records', '今日训练记录');

  String get caloriesInTodayLabel => _t('Calories Intake', '今日摄入热量');
  String todayCaloriesAux(double caloriesIn) => _t(
    'Today intake: ${caloriesIn.toStringAsFixed(0)} kcal',
    '今日已摄入：${caloriesIn.toStringAsFixed(0)} kcal',
  );
  String get exerciseCaloriesTodayLabel => _t('Exercise kcal', '今日运动消耗');
  String get targetIntakeLabel => _t('Target intake', '今日目标摄入');
  String get remainingCaloriesLabel => _t('Remaining', '剩余热量');
  String get macroTargetModeGramPerKg =>
      _t('Macro Targets (g/kg)', '三大营养目标（g/kg）');
  String get gramPerKgModeNotice => _t(
    'g/kg mode uses bodyweight, sex, training-frequency tier, and the current phase table only. It does not mix with calorie deficit or surplus math; kcal is auxiliary.',
    'g/kg 模式只按体重、性别、训练频率档位和当前阶段表计算，不与热量赤字或盈余算法混合；kcal 仅作辅助信息。',
  );
  String get caloriesRingTitle => _t('Calories', '热量');
  String get macrosTitle => _t('Macros', '宏量');
  String get carbsLabelLong => _t('Carbohydrates', '碳水化合物');
  String get foodLabel => _t('Food', '饮食');
  String get gramPerKgHeroTitle => _t("Today's Macro Progress", '今日宏量进度');
  String get gramPerKgHeroModeSuffix => _t('(g/kg)', '（g/kg）');
  String get gramPerKgFocusTitle => _t('Focus next', '优先补充');
  String gramPerKgRemainingHint(double grams) => _t(
    '${grams.toStringAsFixed(0)} g left',
    '还差 ${grams.toStringAsFixed(0)} g',
  );
  String get gramPerKgAllCompleteTitle => _t('Today macros', '今日宏量');
  String get gramPerKgAllCompleteBody => _t('Target reached', '已达到目标');
  String get gramPerKgBalancedHint =>
      _t('All three macros are on track', '三项宏量都已跟上');
  String phaseLabel(String phase) {
    switch (phase) {
      case 'bulking':
        return bulkingLabel;
      case 'cutting':
      default:
        return cuttingLabel;
    }
  }

  String gramPerKgTableTitle(String phase) {
    return phase == 'bulking'
        ? _t('Bulking g/kg table', '增肌期 g/kg 表')
        : _t('Cutting g/kg table', '减脂期 g/kg 表');
  }

  String gramPerKgPhaseNotice(String phase) {
    return phase == 'bulking'
        ? _t(
            'This is the bulking g/kg default table. It gives macro targets directly from bodyweight, sex, and training frequency, without mixing in calorie surplus math.',
            '这是增肌期 g/kg 默认表。它直接按体重、性别和训练频率给出宏量目标，不与热量盈余算法混合计算。',
          )
        : _t(
            'This is the cutting g/kg default table. Carbohydrate coefficients are tuned for cutting and are not a bulking or performance-maximization table.',
            '这是减脂期 g/kg 默认表。碳水系数已按减脂场景调整，不是增肌期表，也不是运动表现最大化表。',
          );
  }

  String energyRatioPhaseNotice(String phase) {
    return phase == 'bulking'
        ? _t(
            'Uses BMR, a training-frequency-based default non-exercise factor, daily calorie surplus, and logged net exercise to calculate target kcal. Local calibration still overrides the default factor when available.',
            '按 BMR、基于训练频率的默认非运动系数、每日热量盈余和当天已记录净运动消耗计算目标 kcal；有本地校准时仍以校准系数优先。',
          )
        : _t(
            'Uses BMR, a training-frequency-based default non-exercise factor, daily calorie deficit, and logged net exercise to calculate target kcal. Local calibration still overrides the default factor when available.',
            '按 BMR、基于训练频率的默认非运动系数、每日热量赤字和当天已记录净运动消耗计算目标 kcal；有本地校准时仍以校准系数优先。',
          );
  }

  String get macroEquivalentEnergyLabel =>
      _t('Macro equivalent energy', '三大营养换算能量');
  String get proteinLabel => _t('Protein', '蛋白质');
  String get carbsLabel => _t('Carbs', '碳水');
  String get fatLabel => _t('Fat', '脂肪');
  String get remainingProteinLabel => _t('Protein remaining (g)', '蛋白质剩余 (g)');
  String get remainingCarbsLabel => _t('Carbs remaining (g)', '碳水剩余 (g)');
  String get remainingFatLabel => _t('Fat remaining (g)', '脂肪剩余 (g)');
  String get tdeeReferenceLabel =>
      _t('No-exercise baseline TDEE', '不运动基线 TDEE');
  String get lifestyleFactorLabel =>
      _t('Lifestyle factor (non-exercise)', '日常活动系数（不含专项训练）');
  String get calibrationConfidenceLabel =>
      _t('Calibration confidence', '校准置信度');
  String get calibrationWindowLabel => _t('Calibration window', '校准窗口');
  String get todayExerciseCaloriesLabel =>
      _t('Today exercise calories', '今日运动消耗');
  String get targetIntakeTodayLabel => _t('Target intake today', '今日目标摄入');
  String get remainingTodayLabel => _t('Remaining today', '今日剩余');

  String strategyLabel(String strategy) {
    switch (strategy) {
      case 'carb_cycling':
        return carbCyclingLabel;
      case 'carb_tapering':
        return carbTaperingLabel;
      case 'none':
      default:
        return strategyNoneLabel;
    }
  }

  String carbDayTypeLabel(String value) {
    switch (value) {
      case 'high':
        return _t('High', '高');
      case 'low':
        return _t('Low', '低');
      case 'medium':
      default:
        return _t('Medium', '中');
    }
  }

  String carbDayTypeFullLabel(String value) =>
      _t('${carbDayTypeLabel(value)} carb day', '${carbDayTypeLabel(value)}碳日');

  String weekdayShortLabel(String key) {
    switch (key) {
      case 'mon':
        return _t('Mon', '周一');
      case 'tue':
        return _t('Tue', '周二');
      case 'wed':
        return _t('Wed', '周三');
      case 'thu':
        return _t('Thu', '周四');
      case 'fri':
        return _t('Fri', '周五');
      case 'sat':
        return _t('Sat', '周六');
      case 'sun':
      default:
        return _t('Sun', '周日');
    }
  }

  String weekdayUltraShortLabel(String key) {
    switch (key) {
      case 'mon':
        return _t('Mon', '一');
      case 'tue':
        return _t('Tue', '二');
      case 'wed':
        return _t('Wed', '三');
      case 'thu':
        return _t('Thu', '四');
      case 'fri':
        return _t('Fri', '五');
      case 'sat':
        return _t('Sat', '六');
      case 'sun':
      default:
        return _t('Sun', '日');
    }
  }

  String carbTaperReviewActionLabel(String action) {
    switch (action) {
      case 'decrease_carbs':
        return _t('Decrease carbs', '降低碳水');
      case 'pause_taper':
        return _t('Pause taper', '暂停渐降');
      case 'increase_carbs_small':
        return _t('Increase carbs a little', '小幅增加碳水');
      case 'blocked_by_safety_floor':
        return _t('Blocked by carb floor', '已触及碳水下限');
      case 'no_data':
        return _t('Need more data', '数据不足');
      case 'keep':
      default:
        return _t('Keep current target', '保持当前目标');
    }
  }

  String carbTaperReasonLabel(String reasonCode) {
    switch (reasonCode) {
      case 'insufficient_weight_logs':
        return _t(
          'Not enough weight logs in this review window yet.',
          '当前复核周期内体重记录还不够。',
        );
      case 'insufficient_food_coverage':
        return _t(
          'Food logging coverage is too low for a reliable adjustment.',
          '饮食记录覆盖率偏低，暂时不适合调整。',
        );
      case 'missing_weight_edges':
        return _t(
          'The start or end of the review window is missing enough weight data.',
          '复核周期起点或终点附近缺少足够体重数据。',
        );
      case 'training_drop_detected':
        return _t(
          'Recent training frequency dropped, so the app keeps the current target for now.',
          '最近训练频率下降，当前先保持目标不变。',
        );
      case 'carb_floor_applied':
        return _t(
          'The carb safety floor is active, so carbs will not be pushed lower.',
          '已触发碳水安全下限，不会继续下调。',
        );
      case 'review_not_due':
        return _t('This review window is not due yet.', '当前还没到下一次复核时间。');
      case 'review_cooldown_active':
        return '';
      default:
        return reasonCode;
    }
  }

  String foodCoverageText(double coverage) => _t(
    'Food log coverage: ${(coverage * 100).toStringAsFixed(0)}%',
    '饮食记录覆盖率：${(coverage * 100).toStringAsFixed(0)}%',
  );

  String trainingDaysText(int days) =>
      _t('Active training days: $days', '有效训练日：$days');

  String targetLossRateText(double rate) => _t(
    'Target: ${rate.toStringAsFixed(2)}% / week',
    '目标：${rate.toStringAsFixed(2)}% / 周',
  );

  String weightTrendText(double rate) => _t(
    'Weight trend: ${rate.toStringAsFixed(2)}% / week',
    '体重趋势：${rate.toStringAsFixed(2)}% / 周',
  );

  String carbOffsetText(double grams) => _t(
    '${grams.toStringAsFixed(0)} g carbs/day',
    '${grams.toStringAsFixed(0)} g 碳水/天',
  );

  String applyCarbDeltaButton(double grams) => _t(
    'Apply ${grams.toStringAsFixed(0)}g carbs/day',
    '应用 ${grams.toStringAsFixed(0)}g 碳水/天',
  );

  String get noSummaryData => _t('No summary data.', '暂无汇总数据。');
  String summaryError(Object error) =>
      _t('Failed to load summary: $error', '加载汇总失败：$error');

  String get nearTarget => _t('Today is close to target', '今日接近目标');

  String remainingCanEat(double kcal) => _t(
    'You can still eat about ${kcal.toStringAsFixed(0)} kcal today',
    '今日距离目标还可摄入约 ${kcal.toStringAsFixed(0)} kcal',
  );

  String remainingExceeded(double kcal) => _t(
    'You exceeded target by about ${kcal.toStringAsFixed(0)} kcal today',
    '今日已超过目标约 ${kcal.toStringAsFixed(0)} kcal',
  );

  String bodyPartLabel(String bodyPart) {
    const map = <String, String>{
      'Chest': '胸部',
      'Back': '背部',
      'Legs': '腿部',
      'Glutes': '臀部',
      'Shoulders': '肩部',
      'Arms': '手臂',
      'Core': '核心',
      'Cardio': '有氧',
      'Full Body': '全身',
    };
    if (!isChinese) {
      return bodyPart;
    }
    return map[bodyPart] ?? bodyPart;
  }

  String shortBodyPartLabel(String bodyPart) {
    const zhMap = <String, String>{
      'Chest': '胸',
      'Back': '背',
      'Legs': '腿',
      'Glutes': '臀',
      'Shoulders': '肩',
      'Arms': '臂',
      'Core': '核心',
      'Cardio': '有氧',
      'Full Body': '全身',
    };
    const enMap = <String, String>{
      'Chest': 'Chest',
      'Back': 'Back',
      'Legs': 'Legs',
      'Glutes': 'Glutes',
      'Shoulders': 'Shoulders',
      'Arms': 'Arms',
      'Core': 'Core',
      'Cardio': 'Cardio',
      'Full Body': 'Full',
    };
    if (isChinese) {
      return zhMap[bodyPart] ?? bodyPart;
    }
    return enMap[bodyPart] ?? bodyPart;
  }

  String exerciseDisplayName(String exerciseName) {
    if (!isChinese) {
      return exerciseName;
    }

    const map = <String, String>{
      'Barbell Flat Bench Press': '杠铃平板卧推',
      'Barbell Incline Bench Press': '杠铃上斜卧推',
      'Dumbbell Flat Bench Press': '哑铃平板卧推',
      'Dumbbell Fly': '哑铃平板飞鸟',
      'Cable Fly': '钢线飞鸟',
      'Machine Chest Press': '坐姿器械推胸',
      'Machine Pec Fly': '坐姿器械夹胸',
      'Kneeling Push-up': '跪姿俯卧撑',
      'Bench Press': '卧推',
      'Incline Dumbbell Press': '哑铃上斜卧推',
      'Push-up': '俯卧撑',
      'Chest Fly': '飞鸟',
      'Pull-up': '引体向上',
      'Assisted Pull-up': '引体向上（辅助）',
      'Lat Pulldown': '高位下拉',
      'Barbell Row': '杠铃划船',
      'Seated Cable Row': '坐姿划船',
      'Seated Row': '坐姿划船',
      'Bent-over Barbell Row': '杠铃俯身划船',
      'Underhand Barbell Row': '杠铃反手划船',
      'Seal Barbell Row': '杠铃海豹划船',
      'Chest-supported T-Bar Row': '俯卧 T-bar 划船',
      'Iso-lateral High Row': '分动式高位划船',
      'Hammer Strength High Row': '分动式高位划船',
      'Barbell High Pull': '杠铃上斜提拉',
      'Barbell Pullover': '杠铃抱拉',
      'Barbell Straight-leg Deadlift': '杠铃直腿硬拉',
      'Single-arm Dumbbell Row': '哑铃俯身单臂提拉',
      'Squat': '深蹲',
      'Bulgarian Split Squat': '保加利亚分腿蹲',
      'Deadlift': '硬拉',
      'Leg Press': '腿举',
      'Romanian Deadlift': '罗马尼亚硬拉',
      'Leg Extension': '腿屈伸',
      'Leg Curl': '腿弯举',
      'Barbell Hip Thrust': '杠铃臀冲',
      'Barbell Overhead Press': '杠铃推举',
      'Overhead Press': '杠铃推举',
      'Lateral Raise': '侧平举',
      'Dumbbell Rear Delt Fly': '哑铃反向飞鸟',
      'Rear Delt Fly': '哑铃反向飞鸟',
      'Standing Dumbbell Shoulder Press': '哑铃站姿推肩',
      'Standing Barbell Shoulder Press': '杠铃站姿推肩',
      'Seated Barbell Shoulder Press': '杠铃坐姿推肩',
      'Standing Barbell Front Raise': '杠铃站姿前平举',
      'Barbell Upright Row': '杠铃提拉',
      'Barbell Biceps Curl': '杠铃二头弯举',
      'Dumbbell Biceps Curl': '哑铃二头弯举',
      'Biceps Curl': '二头弯举',
      'Triceps Pushdown': '三头下压',
      'Hammer Curl': '锤式弯举',
      'Close-grip Bench Press': '杠铃窄距平板卧推',
      'Dip': '双杠臂屈伸',
      'Assisted Dip': '辅助双杠臂屈伸',
      'Plank': '平板支撑',
      'Crunch': '卷腹',
      'Hanging Leg Raise': '悬垂举腿',
      'Running': '跑步',
      'Walking': '步行',
      'Cycling': '骑行',
      'Rowing Machine': '划船机',
      'Stair Climber': '登阶机',
      'Kettlebell Swing': '壶铃摆动',
      'Burpee': '波比跳',
      'Jumping Jack': '开合跳',
    };

    return map[exerciseName] ?? exerciseName;
  }

  String get loading => _t('Loading...', '加载中...');
  String get saving => _t('Saving...', '保存中...');

  String sexOptionLabel(String value) {
    switch (value) {
      case 'male':
        return male;
      case 'female':
        return female;
      case 'prefer_not_to_say':
      default:
        return preferNot;
    }
  }

  String activityOptionLabel(String value) {
    switch (value) {
      case 'sedentary':
        return sedentary;
      case 'lightly_active':
        return lightlyActive;
      case 'very_active':
        return veryActive;
      case 'moderately_active':
      default:
        return moderatelyActive;
    }
  }

  String goalTypeLabel(String value) {
    switch (value) {
      case 'deficit':
        return deficit;
      case 'surplus':
        return surplus;
      case 'maintenance':
      default:
        return maintenance;
    }
  }

  String intensityLabel(String intensity) {
    switch (intensity) {
      case 'low':
        return _t('Low', '低');
      case 'high':
        return _t('High', '高');
      case 'medium':
      default:
        return _t('Medium', '中');
    }
  }

  String cardioIntensityOptionLabel(String value) {
    switch (value) {
      case 'low_60_plus':
        return _t('Low: 60+ minutes', '低强度：60 分钟以上');
      case 'moderate_30_to_60':
        return _t('Moderate: 30-60 minutes', '中等强度：30-60 分钟');
      case 'vigorous_10_to_30':
        return _t('Vigorous: 10-30 minutes', '较高强度：10-30 分钟');
      case 'high_3_to_10':
        return _t('High: 3-10 minutes', '高强度：3-10 分钟');
      case 'interval_under_3':
        return _t(
          'Intervals / very high: under 3 minutes',
          '间歇/极高强度：小于 3 分钟，需要休息',
        );
      default:
        return intensityLabel(value);
    }
  }

  String exerciseStructureLabelFor(String value) {
    switch (value) {
      case 'isolation':
        return _t('Isolation', '孤立动作');
      case 'compound':
      default:
        return _t('Compound', '复合动作');
    }
  }

  String loadInputModeLabel(String value) {
    switch (value) {
      case 'per_side_load':
        return _t('Per-side weight', '每侧重量');
      case 'bodyweight_added':
        return _t('Bodyweight + added load', '自重 + 额外加重');
      case 'assistance_load':
        return _t('Assistance weight', '辅助重量');
      case 'total_load':
      default:
        return _t('Total / machine weight', '总重量 / 器械标称重量');
    }
  }

  String repsInputModeLabel(String value) {
    switch (value) {
      case 'per_side_reps':
        return _t('Per-side reps', '每侧次数');
      case 'total_reps':
      default:
        return _t('Total reps', '总次数');
    }
  }

  String setMetricTypeLabel(String value) {
    switch (value) {
      case 'duration_seconds':
        return _t('Single-set duration', '单组时长');
      case 'reps':
      default:
        return _t('Reps', '次数');
    }
  }

  String setPerformanceLabel({
    required double weightKg,
    required int reps,
    required bool isBodyweightExercise,
    bool isAssistedBodyweightExercise = false,
  }) {
    if (isAssistedBodyweightExercise) {
      return _t(
        'Assist ${weightKg.toStringAsFixed(1)} kg - Reps $reps',
        '辅助 ${weightKg.toStringAsFixed(1)} kg - $reps 次',
      );
    }
    if (isBodyweightExercise) {
      if (weightKg <= 0) {
        return _t('Bodyweight - Reps $reps', '自重 - $reps 次');
      }
      return _t(
        'Bodyweight +${weightKg.toStringAsFixed(1)} kg - Reps $reps',
        '自重 +${weightKg.toStringAsFixed(1)} kg - $reps 次',
      );
    }

    return _t(
      'Weight ${weightKg.toStringAsFixed(1)} kg - Reps $reps',
      '重量 ${weightKg.toStringAsFixed(1)} kg - $reps 次',
    );
  }
}
