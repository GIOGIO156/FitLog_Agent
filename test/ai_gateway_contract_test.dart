import 'package:fitlog_local/core/constants/app_constants.dart';
import 'package:fitlog_local/domain/models/ai_chat_message.dart';
import 'package:fitlog_local/domain/models/ai_chat_session.dart';
import 'package:fitlog_local/domain/models/ai_food_photo_analysis.dart';
import 'package:fitlog_local/domain/models/ai_gateway_error.dart';
import 'package:fitlog_local/domain/models/ai_gateway_request.dart';
import 'package:fitlog_local/domain/models/ai_gateway_response.dart';
import 'package:fitlog_local/domain/models/ai_workout_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI chat history models', () {
    test('AiChatSession parses Supabase row and preserves archive fields', () {
      final session = AiChatSession.fromMap(<String, dynamic>{
        'id': '00000000-0000-4000-8000-000000000001',
        'account_id': 'acct_1',
        'title': 'Dinner',
        'language': 'zh',
        'last_message_at': '2026-06-17T00:00:10Z',
        'archived_at': '2026-06-17T00:01:00Z',
        'deleted_at': null,
        'created_at': '2026-06-17T00:00:00Z',
        'updated_at': '2026-06-17T00:01:00Z',
      });

      expect(session.id, '00000000-0000-4000-8000-000000000001');
      expect(session.accountId, 'acct_1');
      expect(session.title, 'Dinner');
      expect(session.isArchived, isTrue);
      expect(session.isDeleted, isFalse);

      final row = session.toMap();
      expect(row['archived_at'], startsWith('2026-06-17T00:01:00'));
      expect(row['deleted_at'], isNull);
    });

    test('AiChatMessage parses roles and stable message order', () {
      final assistant = AiChatMessage.fromMap(<String, dynamic>{
        'id': 'msg_b',
        'session_id': 'chat_1',
        'account_id': 'acct_1',
        'message_sequence': 2,
        'role': 'assistant',
        'content_text': '可以优先选择鱼虾和蔬菜。',
        'message_type': 'text',
        'workflow_type': 'auto',
        'model_choice': 'chatgpt',
        'model_provider': 'mock',
        'attachments_metadata': <Map<String, dynamic>>[],
        'created_at': '2026-06-17T00:00:01Z',
      });
      final user = AiChatMessage.fromMap(<String, dynamic>{
        'id': 'msg_a',
        'session_id': 'chat_1',
        'account_id': 'acct_1',
        'message_sequence': 1,
        'role': 'user',
        'content_text': '今天晚饭还能吃什么？',
        'message_type': 'text',
        'workflow_type': 'auto',
        'attachments_metadata': <Map<String, dynamic>>[],
        'created_at': '2026-06-17T00:00:01Z',
      });

      final messages = <AiChatMessage>[assistant, user]
        ..sort(AiChatMessage.compareByStableOrder);

      expect(messages.first.role, AiChatMessageRole.user);
      expect(messages.last.role, AiChatMessageRole.assistant);
      expect(assistant.toMap()['role'], 'assistant');
      expect(assistant.attachmentsMetadata, isEmpty);
    });

    test('AiChatMessage rejects unsupported role and message type', () {
      expect(
        () => AiChatMessage.fromMap(<String, dynamic>{
          'id': 'msg_1',
          'session_id': 'chat_1',
          'account_id': 'acct_1',
          'message_sequence': 1,
          'role': 'tool',
          'content_text': 'invalid',
          'message_type': 'text',
          'created_at': '2026-06-17T00:00:01Z',
        }),
        throwsFormatException,
      );

      expect(
        () => AiChatMessage.fromMap(<String, dynamic>{
          'id': 'msg_1',
          'session_id': 'chat_1',
          'account_id': 'acct_1',
          'message_sequence': 1,
          'role': 'user',
          'content_text': 'invalid',
          'message_type': 'image',
          'created_at': '2026-06-17T00:00:01Z',
        }),
        throwsFormatException,
      );
    });
  });

  group('AI Gateway request contract', () {
    test('emits minimal text-only payload without future-phase extras', () {
      const request = AiGatewayRequest(
        sessionId: 'chat_1',
        messageText: '今天还能吃什么？',
        language: 'zh',
        modelChoice: AiGatewayModelChoice.chatgpt,
        selectedDate: '2026-06-17',
        profileVersion: 'profile_42',
        deviceId: 'dev_1',
        client: <String, dynamic>{
          'app_version': '1.0.0',
          'platform': 'android',
          'timezone': 'Asia/Shanghai',
        },
      );

      final json = request.toJson();

      expect(json['session_id'], 'chat_1');
      expect(json['message'], <String, dynamic>{'text': '今天还能吃什么？'});
      expect(json['model_choice'], 'chatgpt');
      expect(json['workflow_hint'], 'auto');
      expect(json['device_id'], 'dev_1');
      expect(json.containsKey('attachments'), isFalse);
      expect(json.containsKey('context_objects'), isFalse);
      expect(json.containsKey('draft'), isFalse);
      expect(json.containsKey('official_record_write'), isFalse);
    });

    test('serializes up to three image attachments for multimodal chat', () {
      const request = AiGatewayRequest(
        messageText: '帮我看看这张图能不能作为晚餐',
        language: 'zh',
        modelChoice: AiGatewayModelChoice.qwen,
        selectedDate: '2026-07-01',
        deviceId: 'dev_1',
        attachments: <AiGatewayImageAttachment>[
          AiGatewayImageAttachment(
            mimeType: 'image/jpeg',
            base64Data: 'abc123',
            byteLength: 128,
            name: 'meal.jpg',
          ),
          AiGatewayImageAttachment(
            mimeType: 'image/png',
            base64Data: 'def456',
            byteLength: 256,
          ),
          AiGatewayImageAttachment(
            mimeType: 'image/webp',
            base64Data: 'ghi789',
            byteLength: 384,
          ),
        ],
      );

      final json = request.toJson();
      final attachments = json['attachments'] as List<dynamic>;

      expect(attachments, hasLength(3));
      expect(attachments.first['kind'], 'image');
      expect(attachments.first['mime_type'], 'image/jpeg');
      expect(attachments.last['mime_type'], 'image/webp');
      expect(json.containsKey('official_record_write'), isFalse);
      expect(json.containsKey('rag_context'), isFalse);
    });

    test('serializes compact conversation context without future extras', () {
      const request = AiGatewayRequest(
        messageText: '那训练呢？',
        language: 'zh',
        modelChoice: AiGatewayModelChoice.qwen,
        deviceId: 'dev_1',
        conversationContext: AiGatewayConversationContext(
          messages: <AiGatewayContextMessage>[
            AiGatewayContextMessage(role: 'user', text: '刚才那张饭图能记录吗？'),
            AiGatewayContextMessage(role: 'assistant', text: '已生成饮食草稿。'),
          ],
          artifacts: <AiGatewayArtifactSummary>[
            AiGatewayArtifactSummary(
              type: 'food_draft',
              title: 'Chicken rice',
              summary: 'Food draft artifact, about 520 kcal',
            ),
          ],
        ),
      );

      final json = request.toJson();
      final context = json['conversation_context'] as Map<String, dynamic>;

      expect(context['messages'], hasLength(2));
      expect(context['artifacts'], hasLength(1));
      expect(json.containsKey('context_objects'), isFalse);
      expect(json.containsKey('rag_context'), isFalse);
    });
  });

  group('AI Gateway response contract', () {
    test('parses successful assistant text response', () {
      final response = AiGatewayResponse.fromJson(<String, dynamic>{
        'session_id': 'chat_1',
        'assistant_message_id': 'msg_2',
        'model_choice': 'chatgpt',
        'model_provider': 'openai',
        'message': <String, dynamic>{
          'text': '晚饭可以优先选择瘦肉或鱼虾。',
          'language': 'zh',
        },
        'workflow': 'meal_decision',
        'needs_clarification': false,
        'clarification_questions': <String>[],
        'draft': null,
        'error': null,
        'debug_summary_id': 'dbg_1',
      });

      expect(response.isSuccess, isTrue);
      expect(response.canShowAssistantText, isTrue);
      expect(response.modelChoice, AiGatewayModelChoice.chatgpt);
      expect(response.modelProvider, 'openai');
      expect(response.messageText, '晚饭可以优先选择瘦肉或鱼虾。');
      expect(response.debugSummaryId, 'dbg_1');
      expect(response.hasUnsupportedDraftPayload, isFalse);
    });

    test('parses clarification and a saveable draft payload', () {
      final response = AiGatewayResponse.fromJson(<String, dynamic>{
        'workflow': 'food_logging',
        'needs_clarification': true,
        'clarification_questions': <String>['这份食物的重量大概是多少？'],
        'draft': _validDraftJson(),
      });

      expect(response.needsClarification, isTrue);
      expect(response.clarificationQuestions, hasLength(1));
      expect(response.foodDraft?.mealName, 'Chicken rice');
      expect(response.hasUnsupportedDraftPayload, isFalse);
      expect(response.toJson()['draft'], isNotNull);
    });

    test('parses a workout draft payload', () {
      final response = AiGatewayResponse.fromJson(<String, dynamic>{
        'workflow': 'auto',
        'draft': _validWorkoutDraftJson(),
      });

      expect(response.workoutDraft?.recordName, 'Bench press');
      expect(response.workoutDraft?.exercises.single.sets, hasLength(1));
      expect(response.foodDraft, isNull);
      expect(response.hasUnsupportedDraftPayload, isFalse);
    });

    test('maps stable and unknown error codes', () {
      final replaced = AiGatewayResponse.fromJson(<String, dynamic>{
        'error': <String, dynamic>{
          'code': 'device_replaced',
          'message': 'Internal details must not be shown directly.',
        },
      });
      final unknown = AiGatewayResponse.fromJson(<String, dynamic>{
        'error': <String, dynamic>{'code': 'provider_raw_500'},
      });

      expect(replaced.isSuccess, isFalse);
      expect(replaced.error?.code, AiGatewayErrorCode.deviceReplaced);
      expect(replaced.error?.isDeviceReplaced, isTrue);
      expect(unknown.error?.code, AiGatewayErrorCode.unknown);
      expect(unknown.error?.rawCode, 'provider_raw_500');
    });
  });

  group('AI food analysis contract', () {
    test('serializes the photo analysis request without future extras', () {
      const request = AiFoodPhotoAnalysisRequest(
        images: <AiFoodPhotoImagePayload>[
          AiFoodPhotoImagePayload(
            mimeType: 'image/jpeg',
            base64Data: 'abc123',
            byteLength: 128,
          ),
          AiFoodPhotoImagePayload(
            mimeType: 'image/png',
            base64Data: 'def456',
            byteLength: 256,
          ),
        ],
        language: 'zh',
        deviceId: 'device-a',
        selectedDate: '2026-07-01',
        userNote: '米饭只吃了一半',
      );

      final json = request.toJson();

      expect(json['model_choice'], 'qwen');
      expect(json['schema_version'], aiFoodDraftSchemaVersion);
      expect(json['official_record_write'], isNull);
      expect(json['rag_context'], isNull);
      final images = json['images'] as List<dynamic>;
      expect(images, hasLength(2));
      expect((images.first as Map<String, dynamic>)['byte_length'], 128);
    });

    test('serializes a text-only food analysis request', () {
      const request = AiFoodPhotoAnalysisRequest(
        images: <AiFoodPhotoImagePayload>[],
        language: 'zh',
        deviceId: 'device-a',
        selectedDate: '2026-07-01',
        userNote: '100g 三文鱼',
      );

      final json = request.toJson();

      expect(json['images'], isEmpty);
      expect(json['user_note'], '100g 三文鱼');
      expect(json['official_record_write'], isNull);
    });

    test('parses a valid food draft response', () {
      final response = AiFoodPhotoAnalysisResponse.fromJson(<String, dynamic>{
        'model_choice': 'qwen',
        'model_provider': 'qwen',
        'needs_clarification': false,
        'clarification_questions': <String>[],
        'debug_summary_id': 'dbg_1',
        'draft': _validDraftJson(),
      });

      expect(response.isSuccess, isTrue);
      expect(response.modelChoice, AiGatewayModelChoice.qwen);
      expect(response.draft?.mealName, 'Chicken rice');
      expect(response.draft?.items, hasLength(1));
    });

    test('rejects invalid numeric draft fields', () {
      expect(
        () => AiFoodPhotoAnalysisResponse.fromJson(<String, dynamic>{
          'draft': <String, dynamic>{
            ..._validDraftJson(),
            'calories_kcal': double.nan,
          },
        }),
        throwsFormatException,
      );
    });

    test('converts a draft to an AI food analysis FoodRecord', () {
      final draft = AiFoodDraft.fromJson(_validDraftJson());

      final record = draft.toFoodRecord(
        date: '2026-07-01',
        modelProvider: 'qwen',
        userNote: '少吃了米饭',
      );

      expect(record.source, AppConstants.sourceAiPhoto);
      expect(record.date, '2026-07-01');
      expect(record.items.single.name, 'Chicken');
      expect(record.estimationNotes, contains('qwen'));
      expect(record.estimationNotes, contains('少吃了米饭'));
    });
  });

  group('AI workout draft contract', () {
    test('converts a workout draft to the existing editor payload', () {
      final draft = AiWorkoutDraft.fromJson(_validWorkoutDraftJson());

      final recordDraft = draft.toWorkoutRecordDraft(
        dateFallback: '2026-07-02',
        now: DateTime.utc(2026, 7, 2, 12),
      );

      expect(recordDraft.kind, 'new_record');
      expect(recordDraft.date, '2026-07-02');
      expect(recordDraft.exerciseCount, 1);
      expect(recordDraft.firstExerciseName, 'Barbell Flat Bench Press');
      expect(recordDraft.payload['exercises'], hasLength(1));
    });
  });
}

Map<String, dynamic> _validDraftJson() {
  return <String, dynamic>{
    'meal_name': 'Chicken rice',
    'total_weight_g': 320,
    'calories_kcal': 520,
    'protein_g': 32,
    'carbs_g': 62,
    'fat_g': 14,
    'confidence': 0.72,
    'estimation_notes': 'Estimated from visible plate.',
    'items': <Map<String, dynamic>>[
      <String, dynamic>{
        'name': 'Chicken',
        'weight_g': 120,
        'calories_kcal': 220,
        'protein_g': 28,
        'carbs_g': 0,
        'fat_g': 10,
      },
    ],
  };
}

Map<String, dynamic> _validWorkoutDraftJson() {
  return <String, dynamic>{
    'schema_version': aiWorkoutDraftSchemaVersion,
    'record_name': 'Bench press',
    'date': null,
    'notes': 'Generated by AI chat.',
    'exercises': <Map<String, dynamic>>[
      <String, dynamic>{
        'exercise_name': '卧推',
        'exercise_key': null,
        'exercise_type': 'strength',
        'body_part': null,
        'duration_minutes': null,
        'active_duration_minutes': null,
        'cardio_intensity_basis': null,
        'sets': <Map<String, dynamic>>[
          <String, dynamic>{
            'weight_kg': 20,
            'reps': 10,
            'duration_seconds': null,
          },
        ],
      },
    ],
  };
}
