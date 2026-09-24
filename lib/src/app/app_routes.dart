import 'package:flutter/widgets.dart';
import 'package:kaisel/kaisel.dart';

import '../features/about/about_screen.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/legal/privacy_policy_screen.dart';
import '../features/legal/terms_of_service_screen.dart';
import '../features/shell/school_shell.dart';

sealed class AppRoute extends KaiselRoute {
  const AppRoute();
}

final class SignInRoute extends AppRoute {
  const SignInRoute();

  @override
  String get routeName => 'sign_in';
}

final class MainShellRoute extends AppRoute {
  const MainShellRoute();

  @override
  String get routeName => 'main_shell';
}

final class AboutRoute extends AppRoute {
  const AboutRoute();

  @override
  String get routeName => 'about';
}

final class PrivacyPolicyRoute extends AppRoute {
  const PrivacyPolicyRoute();

  @override
  String get routeName => 'privacy_policy';
}

final class TermsOfServiceRoute extends AppRoute {
  const TermsOfServiceRoute();

  @override
  String get routeName => 'terms_of_service';
}

sealed class DashboardBranchRoute extends KaiselRoute {
  const DashboardBranchRoute();
}

final class DashboardHomeRoute extends DashboardBranchRoute {
  const DashboardHomeRoute();

  @override
  String get routeName => 'dashboard_home';
}

sealed class ChannelsBranchRoute extends KaiselRoute {
  const ChannelsBranchRoute();
}

final class ChannelsHomeRoute extends ChannelsBranchRoute {
  const ChannelsHomeRoute();

  @override
  String get routeName => 'channels_home';
}

final class ChannelDetailBranchRoute extends ChannelsBranchRoute {
  const ChannelDetailBranchRoute(this.channelId);

  final String channelId;

  @override
  List<Object?> get props => [channelId];

  @override
  String get routeName => 'channel_detail';
}

sealed class ResourcesBranchRoute extends KaiselRoute {
  const ResourcesBranchRoute();
}

final class ResourcesHomeRoute extends ResourcesBranchRoute {
  const ResourcesHomeRoute();

  @override
  String get routeName => 'resources_home';
}

sealed class MeetingsBranchRoute extends KaiselRoute {
  const MeetingsBranchRoute();
}

final class MeetingsHomeRoute extends MeetingsBranchRoute {
  const MeetingsHomeRoute();

  @override
  String get routeName => 'meetings_home';
}

sealed class ProjectsBranchRoute extends KaiselRoute {
  const ProjectsBranchRoute();
}

final class ProjectsHomeRoute extends ProjectsBranchRoute {
  const ProjectsHomeRoute();

  @override
  String get routeName => 'projects_home';
}

sealed class CommunityBranchRoute extends KaiselRoute {
  const CommunityBranchRoute();
}

final class CommunityHomeRoute extends CommunityBranchRoute {
  const CommunityHomeRoute();

  @override
  String get routeName => 'community_home';
}

abstract final class SchoolBranch {
  static const dashboard = 0;
  static const channels = 1;
  static const resources = 2;
  static const meetings = 3;
  static const projects = 4;
  static const community = 5;
}

final appRouterConfig = KaiselRouterConfig<AppRoute>(
  initial: const SignInRoute(),
  builder: (context, route) => switch (route) {
    SignInRoute() => const SignInScreen(),
    MainShellRoute() => const SchoolShell(),
    AboutRoute() => const AboutScreen(),
    PrivacyPolicyRoute() => const PrivacyPolicyScreen(),
    TermsOfServiceRoute() => const TermsOfServiceScreen(),
  },
  codec: StackToConfigCodec<AppRoute>(const AppRouteCodec()),
  fallback: const [MainShellRoute()],
);

class AppRouteCodec implements KaiselStackCodec<AppRoute> {
  const AppRouteCodec();

  @override
  Uri encode(List<AppRoute> stack) {
    return switch (stack.last) {
      SignInRoute() => Uri(path: '/sign-in'),
      MainShellRoute() => Uri(path: '/'),
      AboutRoute() => Uri(path: '/about'),
      PrivacyPolicyRoute() => Uri(path: '/privacy'),
      TermsOfServiceRoute() => Uri(path: '/terms'),
    };
  }

  @override
  List<AppRoute>? decode(Uri uri) {
    return switch (uri.pathSegments) {
      ['sign-in'] => const [SignInRoute()],
      ['about'] => const [MainShellRoute(), AboutRoute()],
      ['privacy' || 'privacy-policy'] => const [MainShellRoute(), PrivacyPolicyRoute()],
      ['terms' || 'terms-of-service'] => const [MainShellRoute(), TermsOfServiceRoute()],
      _ => const [MainShellRoute()],
    };
  }
}

void goTo(AppRoute route) {
  // Authentication transitions replace the whole root stack so an
  // authenticated user cannot navigate back to the sign-in screen (and a
  // signed-out user cannot navigate forward into the application shell).
  appRouterConfig.router.set([route]);
}

void switchToBranch(BuildContext context, int branch) {
  context.shell().switchTo(branch);
}
