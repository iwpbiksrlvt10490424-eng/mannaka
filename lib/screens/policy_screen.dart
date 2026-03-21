import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('プライバシーポリシー'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _PolicyContent(
          header: 'Aima プライバシーポリシー\n制定日：2024年4月1日\n最終改定日：2026年3月17日',
          sections: [
            _PolicySection(
              title: '第1条（個人情報の定義）',
              content:
                  '本プライバシーポリシーにおける「個人情報」とは、個人情報の保護に関する法律（個人情報保護法）に定める個人情報、すなわち生存する個人に関する情報であって、当該情報に含まれる氏名・生年月日その他の記述等によって特定の個人を識別することができるもの（他の情報と容易に照合することができ、それにより特定の個人を識別することができるものを含む。）をいいます。',
            ),
            _PolicySection(
              title: '第2条（収集する情報および利用目的）',
              content:
                  '当アプリは、以下の情報を収集し、それぞれの目的に利用します。\n\n'
                  '【位置情報（GPS）】\n'
                  '利用目的：みんなにとってちょうどいい集合スポットの提案、周辺のお店情報取得\n'
                  '保存場所：端末内のみ（サーバーへの送信なし）\n'
                  '保存期間：アプリ利用中のみ使用。アプリ終了後は保持しません。\n\n'
                  '【入力された駅情報・プロフィール情報】\n'
                  '利用目的：アプリ機能の提供（出発駅の自動入力、ホーム駅の設定等）\n'
                  '保存場所：端末内のSharedPreferences\n'
                  '保存期間：ユーザーがアプリを削除するまで保持\n'
                  '※利用統計機能（オプトイン）を有効にした場合、ホーム駅情報が匿名IDとともにFirebaseに送信されます。\n\n'
                  '【飲食記録・検索履歴】\n'
                  '利用目的：履歴表示・再検索機能の提供\n'
                  '保存場所：端末内のみ\n'
                  '保存期間：ユーザーが削除するまで保持\n\n'
                  '【クラッシュレポート・利用統計（匿名）】\n'
                  '利用目的：アプリの安定性向上・機能改善\n'
                  '保存場所：Firebase（Google LLC）のサーバー\n'
                  '内容：端末種別、OSバージョン、クラッシュ情報等（個人を特定できない匿名情報）',
            ),
            _PolicySection(
              title: '第3条（第三者サービスへの情報提供）',
              content:
                  '当アプリは以下の外部サービスを利用しており、それぞれのサービスに対して必要な情報が送信される場合があります。\n\n'
                  '【株式会社リクルート（Hotpepper グルメAPI）】\n'
                  '提供情報：検索時の緯度・経度、検索条件\n'
                  '利用目的：周辺レストラン情報の取得\n'
                  'プライバシーポリシー：https://www.recruit.co.jp/privacy/\n\n'
                  '【Google LLC（Firebase）】\n'
                  '提供情報：匿名の利用統計・クラッシュ情報\n'
                  '利用目的：アプリ品質改善\n'
                  'プライバシーポリシー：https://policies.google.com/privacy\n\n'
                  '上記以外の第三者に対し、ユーザーの同意なく個人情報を提供することはありません。ただし、法令に基づく開示が必要な場合はこの限りではありません。',
            ),
            _PolicySection(
              title: '第4条（個人情報の安全管理）',
              content:
                  '当アプリは、収集した個人情報の漏洩、滅失、毀損の防止のため、以下の安全管理措置を講じます。\n\n'
                  '・位置情報は端末内でのみ処理し、外部サーバーへ送信しません\n'
                  '・外部APIへの通信はHTTPS（TLS暗号化）を使用します\n'
                  '・端末内データはOSが提供するセキュアな保存領域（Keychain/SharedPreferences）を使用します\n'
                  '・個人情報を含む情報をログに記録しません',
            ),
            _PolicySection(
              title: '第5条（個人情報の開示・訂正・削除）',
              content:
                  'ユーザーは、当アプリが保有する自己の個人情報について、以下の方法により確認・削除できます。\n\n'
                  '・プロフィール情報：マイページ画面から編集・削除が可能です\n'
                  '・検索履歴・飲食記録：履歴画面から削除が可能です\n'
                  '・お気に入り駅：マイページ > お気に入りの駅から削除が可能です\n'
                  '・全データ削除：アプリをアンインストールすることで端末内の全データが削除されます\n\n'
                  '上記以外の開示・訂正等のご要望は、第7条に記載のお問い合わせ窓口までご連絡ください。当アプリは法令の定める期間内に対応します。',
            ),
            _PolicySection(
              title: '第6条（未成年者の個人情報）',
              content:
                  '当アプリは、13歳未満のお子様の個人情報を意図的に収集しません。13歳未満の方はアプリをご利用いただく前に保護者の方の同意を得てください。13歳未満の方の個人情報が収集されていることが判明した場合は、速やかに削除します。',
            ),
            _PolicySection(
              title: '第7条（プライバシーポリシーの変更）',
              content:
                  '当アプリは、法令の変更・サービス内容の変更等に応じて、本プライバシーポリシーを改定する場合があります。重要な変更がある場合は、アプリ内でのお知らせ等により通知します。改定後も当アプリをご利用いただいた場合は、改定後のプライバシーポリシーに同意したものとみなします。',
            ),
            _PolicySection(
              title: '第8条（お問い合わせ）',
              content:
                  '本プライバシーポリシーに関するご質問・ご要望は、以下の窓口までお問い合わせください。\n\n'
                  'メールアドレス：support@mannaka.app\n\n'
                  '準拠法：日本法\n'
                  '管轄裁判所：東京地方裁判所',
            ),
          ],
        ),
      ),
    );
  }
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('利用規約'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _PolicyContent(
          header: 'Aima 利用規約\n制定日：2024年4月1日\n最終改定日：2025年3月15日',
          sections: [
            _PolicySection(
              title: '第1条（本規約の適用）',
              content:
                  '本利用規約（以下「本規約」）は、Aima（以下「当アプリ」）が提供するサービス（以下「本サービス」）の利用条件を定めるものです。ユーザーは本サービスを利用することにより、本規約に同意したものとみなします。なお、ユーザーが未成年者の場合は、保護者の同意を得た上でご利用ください。',
            ),
            _PolicySection(
              title: '第2条（サービスの内容）',
              content:
                  '本サービスは、複数ユーザーの出発駅から公平な移動時間を考慮した集合場所（飲食店等）を提案するアプリケーションです。提案するお店情報はホットペッパーグルメAPIその他の外部サービスから取得しており、情報の正確性・完全性・最新性を保証するものではありません。',
            ),
            _PolicySection(
              title: '第3条（アカウント）',
              content:
                  '本サービスは会員登録不要でご利用いただけます。ユーザーは任意でニックネーム等のプロフィール情報を端末内に設定できますが、当該情報の管理責任はユーザー自身が負います。端末の紛失・盗難等によって生じた損害について、当アプリは一切の責任を負いません。',
            ),
            _PolicySection(
              title: '第4条（禁止事項）',
              content:
                  'ユーザーは、本サービスの利用にあたり以下の行為を行ってはなりません。\n\n'
                  '一　法令または公序良俗に違反する行為\n'
                  '二　犯罪行為に関連する行為\n'
                  '三　当アプリ、他のユーザー、または第三者のサーバーやネットワークに過度な負荷をかける行為\n'
                  '四　当アプリのサービス運営を妨害するおそれのある行為\n'
                  '五　他のユーザーに関する個人情報等を収集または蓄積する行為\n'
                  '六　不正アクセスをし、またはこれを試みる行為\n'
                  '七　当アプリのシステムをリバースエンジニアリング、逆コンパイル、逆アセンブルする行為\n'
                  '八　本サービスを商業目的で無断利用する行為\n'
                  '九　その他、当アプリが不適切と判断する行為',
            ),
            _PolicySection(
              title: '第5条（知的財産権）',
              content:
                  '本サービスに関連するすべての知的財産権（著作権、商標権等）は、当アプリまたは正当な権利者に帰属します。本規約に基づくサービスの利用許諾は、本サービスに関する知的財産権の譲渡を意味するものではありません。ユーザーは、当アプリの書面による事前の承諾なく、本サービスのコンテンツを複製・転載・改変・販売・配布することはできません。',
            ),
            _PolicySection(
              title: '第6条（サービスの変更・停止）',
              content:
                  '当アプリは、以下の場合にサービスの全部または一部を変更、一時停止、または終了することがあります。\n\n'
                  '・システムメンテナンスを行う場合\n'
                  '・天災、停電、通信障害等の不可抗力が生じた場合\n'
                  '・外部サービス（API等）の提供が停止された場合\n'
                  '・その他、当アプリが必要と判断した場合\n\n'
                  'これらによってユーザーに損害が生じた場合であっても、当アプリは一切の責任を負いません。',
            ),
            _PolicySection(
              title: '第7条（免責事項）',
              content:
                  '当アプリは以下について一切の責任を負いません。\n\n'
                  '・本サービスが提供するお店情報の正確性、完全性、最新性\n'
                  '・本サービスを通じた予約・利用に関してユーザーとお店との間に生じたトラブル\n'
                  '・位置情報の精度に起因する損害\n'
                  '・本サービスの利用または利用不能によって生じた直接・間接の損害\n'
                  '・第三者が本サービスに関連して行った行為により生じた損害\n\n'
                  '当アプリが責任を負う場合においても、その賠償額はユーザーが被った実損害額を上限とします。',
            ),
            _PolicySection(
              title: '第8条（利用規約の変更）',
              content:
                  '当アプリは、必要と判断した場合には、ユーザーへの通知なく本規約を変更できるものとします。変更後の規約は、当アプリ所定の方法により通知した時点から効力を生じます。変更後も本サービスをご利用いただいた場合は、変更後の規約に同意したものとみなします。',
            ),
            _PolicySection(
              title: '第9条（準拠法・管轄裁判所）',
              content:
                  '本規約の解釈にあたっては、日本法を準拠法とします。本サービスに関して紛争が生じた場合には、東京地方裁判所を第一審の専属的合意管轄裁判所とします。',
            ),
            _PolicySection(
              title: '第10条（お問い合わせ）',
              content:
                  '本規約に関するご質問は、以下の窓口までお問い合わせください。\n\nメールアドレス：support@mannaka.app',
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 共通コンポーネント ─────────────────────────────────────────────────────

class _PolicySection {
  const _PolicySection({required this.title, required this.content});
  final String title;
  final String content;
}

class _PolicyContent extends StatelessWidget {
  const _PolicyContent({required this.sections, this.header});
  final List<_PolicySection> sections;
  final String? header;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) ...[
          Text(
            header!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 16),
        ],
        ...sections.map((s) => _SectionWidget(section: s)),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SectionWidget extends StatelessWidget {
  const _SectionWidget({required this.section});
  final _PolicySection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}
