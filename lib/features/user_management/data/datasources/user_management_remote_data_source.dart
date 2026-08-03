import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/rbac/permission.dart';
import '../../../../core/rbac/rbac_manager.dart';
import '../models/managed_user_model.dart';
import '../models/role_model.dart';

abstract class UserManagementRemoteDataSource {
  Future<List<ManagedUserModel>> getAllUsers();
  Future<ManagedUserModel> createUser({
    required String email,
    required String password,
    required String displayName,
    required String roleId,
    String? employeeId,
    String? employeeName,
  });
  Future<void> updateUser(ManagedUserModel user);
  Future<void> toggleUserStatus(String uid, bool isActive);
  Future<void> changeUserPassword({
    required String uid,
    required String newPassword,
  });

  Future<List<RoleModel>> getAllRoles();
  Future<RoleModel> createRole(RoleModel role);
  Future<void> updateRole(RoleModel role);
  Future<void> deleteRole(String roleId);
  Future<void> seedDefaultRoles();
}

class UserManagementRemoteDataSourceImpl
    implements UserManagementRemoteDataSource {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  UserManagementRemoteDataSourceImpl({
    required this.auth,
    required this.firestore,
  });

  bool _isEmailDocId(String id) => id.contains('@');

  Future<Map<String, String>> _roleNameMap() async {
    final rolesSnapshot = await firestore.collection('roles').get();
    final roleMap = <String, String>{};
    for (final doc in rolesSnapshot.docs) {
      roleMap[doc.id] = doc.data()['name'] ?? doc.id;
    }
    return roleMap;
  }

  Future<void> _syncLegacyAllowedUser({
    required String email,
    required bool isActive,
    required String roleId,
  }) async {
    if (email.isEmpty) return;
    final normalized = RbacManager.normalizeRoleId(roleId);
    await firestore.collection('allowed_users').doc(email.toLowerCase()).set({
      'active': isActive,
      'isAdmin': RbacManager.roleIsAdmin(normalized),
      'roleId': normalized,
    }, SetOptions(merge: true));
  }

  /// Removes legacy email-keyed duplicates after writing the canonical uid doc.
  Future<void> _deleteLegacyEmailDoc(String email, String uid) async {
    if (email.isEmpty) return;
    final emailKey = email.toLowerCase();
    if (emailKey == uid) return;
    final legacy = firestore.collection('users').doc(emailKey);
    final snap = await legacy.get();
    if (snap.exists) {
      await legacy.delete();
    }
  }

  /// Link / unlink login account on the employee document.
  Future<void> _syncEmployeeLink({
    required String uid,
    required String email,
    String? employeeId,
    String? previousEmployeeId,
  }) async {
    // Clear previous employee link if changed
    if (previousEmployeeId != null &&
        previousEmployeeId.isNotEmpty &&
        previousEmployeeId != employeeId) {
      try {
        await firestore.collection('employees').doc(previousEmployeeId).set({
          'linkedUserUid': FieldValue.delete(),
          'linkedUserEmail': FieldValue.delete(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    if (employeeId == null || employeeId.isEmpty) {
      return;
    }

    await firestore.collection('employees').doc(employeeId).set({
      'linkedUserUid': uid,
      'linkedUserEmail': email.toLowerCase(),
    }, SetOptions(merge: true));
  }

  @override
  Future<List<ManagedUserModel>> getAllUsers() async {
    try {
      final roleMap = await _roleNameMap();
      final usersSnapshot = await firestore.collection('users').get();

      // Prefer canonical uid docs; skip email-as-id duplicates.
      final byUid = <String, ManagedUserModel>{};
      final emailOnlyFallback = <String, ManagedUserModel>{};

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final roleId = data['roleId'] as String? ?? '';
        final roleName = roleMap[roleId] ?? roleId;
        final model = ManagedUserModel.fromFirestore(doc, roleName: roleName);
        final email = model.email.toLowerCase();

        if (_isEmailDocId(doc.id)) {
          // Legacy email-keyed doc — only use if no uid doc appears later.
          if (email.isNotEmpty) {
            emailOnlyFallback[email] = model;
          }
          continue;
        }

        byUid[model.uid] = model;
      }

      // Include legacy email-only users that have no uid counterpart.
      final existingEmails =
          byUid.values.map((u) => u.email.toLowerCase()).toSet();
      for (final entry in emailOnlyFallback.entries) {
        if (!existingEmails.contains(entry.key)) {
          byUid['legacy_${entry.key}'] = entry.value;
        }
      }

      // Resolve employee profile photos for linked users
      final employeeIds = byUid.values
          .map((u) => u.employeeId)
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toSet()
          .toList();

      final photoByEmployeeId = <String, String>{};
      // Firestore getAll in chunks of 10 via Future.wait individual gets (simple & reliable)
      await Future.wait(
        employeeIds.map((id) async {
          try {
            final snap = await firestore.collection('employees').doc(id).get();
            final url = snap.data()?['imageUrl'] as String?;
            if (url != null && url.trim().isNotEmpty) {
              photoByEmployeeId[id] = url.trim();
            }
          } catch (_) {}
        }),
      );

      final list = byUid.values.map((u) {
        final empId = u.employeeId;
        if (empId == null || empId.isEmpty) return u;
        final photo = photoByEmployeeId[empId];
        if (photo == null) return u;
        return u.copyWithPhoto(photo);
      }).toList()
        ..sort((a, b) {
          final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      return list;
    } catch (e) {
      throw ServerException('Failed to fetch users: $e');
    }
  }

  @override
  Future<ManagedUserModel> createUser({
    required String email,
    required String password,
    required String displayName,
    required String roleId,
    String? employeeId,
    String? employeeName,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // Prevent duplicate by email in users collection
      final existing = await firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        throw ServerException('A user with this email already exists.');
      }
      final legacyEmailDoc =
          await firestore.collection('users').doc(normalizedEmail).get();
      if (legacyEmailDoc.exists) {
        throw ServerException('A user with this email already exists.');
      }

      // Prevent two logins linked to the same employee
      if (employeeId != null && employeeId.isNotEmpty) {
        final linked = await firestore
            .collection('users')
            .where('employeeId', isEqualTo: employeeId)
            .limit(1)
            .get();
        if (linked.docs.isNotEmpty) {
          throw ServerException(
            'This employee is already linked to another login account.',
          );
        }
      }

      // Secondary Firebase App so admin session is preserved
      FirebaseApp secondaryApp;
      try {
        secondaryApp = Firebase.app('SecondaryApp');
      } catch (_) {
        secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );
      }

      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final newUser = userCredential.user;
      if (newUser == null) {
        throw ServerException('Failed to create user account.');
      }

      try {
        await newUser.updateDisplayName(displayName);
      } catch (_) {}

      await secondaryAuth.signOut();

      final currentUserUid = auth.currentUser?.uid ?? 'system';
      final roleMap = await _roleNameMap();
      final roleName = roleMap[roleId] ?? roleId;

      final normalizedRoleId = RbacManager.normalizeRoleId(roleId);
      final userModel = ManagedUserModel(
        uid: newUser.uid,
        email: normalizedEmail,
        displayName: displayName,
        roleId: normalizedRoleId,
        roleName: roleMap[normalizedRoleId] ?? roleName,
        isActive: true,
        createdAt: DateTime.now(),
        createdBy: currentUserUid,
        employeeId: employeeId,
        employeeName: employeeName,
      );

      // Single canonical document: users/{uid}
      await firestore
          .collection('users')
          .doc(newUser.uid)
          .set(userModel.toFirestore());

      await _syncEmployeeLink(
        uid: newUser.uid,
        email: normalizedEmail,
        employeeId: employeeId,
      );

      await _syncLegacyAllowedUser(
        email: normalizedEmail,
        isActive: true,
        roleId: roleId,
      );

      // Clean up any accidental email-keyed doc
      await _deleteLegacyEmailDoc(normalizedEmail, newUser.uid);

      return userModel;
    } on FirebaseAuthException catch (e) {
      throw AuthenticationException(e.message ?? 'User creation failed');
    } on AuthenticationException {
      rethrow;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('Failed to create user: $e');
    }
  }

  @override
  Future<void> updateUser(ManagedUserModel user) async {
    try {
      final email = user.email.toLowerCase();
      final payload = user.toFirestoreUpdate();

      final existing =
          await firestore.collection('users').doc(user.uid).get();
      final previousEmployeeId =
          existing.data()?['employeeId'] as String?;

      // Another login already linked to this employee?
      if (user.employeeId != null && user.employeeId!.isNotEmpty) {
        final linked = await firestore
            .collection('users')
            .where('employeeId', isEqualTo: user.employeeId)
            .limit(2)
            .get();
        final conflict = linked.docs.any((d) => d.id != user.uid);
        if (conflict) {
          throw ServerException(
            'This employee is already linked to another login account.',
          );
        }
      }

      await firestore.collection('users').doc(user.uid).set({
        ...payload,
        'createdAt': user.createdAt != null
            ? Timestamp.fromDate(user.createdAt!)
            : FieldValue.serverTimestamp(),
        'createdBy': user.createdBy,
      }, SetOptions(merge: true));

      await _syncEmployeeLink(
        uid: user.uid,
        email: email,
        employeeId: user.employeeId,
        previousEmployeeId: previousEmployeeId,
      );

      // Sync / remove legacy email doc
      await _deleteLegacyEmailDoc(email, user.uid);

      await _syncLegacyAllowedUser(
        email: email,
        isActive: user.isActive,
        roleId: user.roleId,
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to update user: $e');
    }
  }

  @override
  Future<void> toggleUserStatus(String uid, bool isActive) async {
    try {
      final docRef = firestore.collection('users').doc(uid);
      final snap = await docRef.get();

      String? email;
      String roleId = 'office_staff';

      if (snap.exists) {
        final data = snap.data() ?? {};
        email = (data['email'] as String?)?.toLowerCase();
        roleId = data['roleId'] as String? ?? roleId;
        await docRef.update({'isActive': isActive});
      } else {
        // Legacy: email used as doc id
        final byEmailQuery = await firestore
            .collection('users')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();
        if (byEmailQuery.docs.isNotEmpty) {
          final d = byEmailQuery.docs.first;
          email = (d.data()['email'] as String?)?.toLowerCase();
          roleId = d.data()['roleId'] as String? ?? roleId;
          await d.reference.update({'isActive': isActive});
        } else {
          throw ServerException('User not found.');
        }
      }

      if (email != null && email.isNotEmpty) {
        // Update legacy email-keyed doc if present
        final legacy = firestore.collection('users').doc(email);
        final legacySnap = await legacy.get();
        if (legacySnap.exists) {
          await legacy.update({'isActive': isActive});
        }
        await _syncLegacyAllowedUser(
          email: email,
          isActive: isActive,
          roleId: roleId,
        );
      }
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to update user status: $e');
    }
  }

  @override
  Future<void> changeUserPassword({
    required String uid,
    required String newPassword,
  }) async {
    if (uid.isEmpty) {
      throw ServerException('User id is required.');
    }
    if (newPassword.length < 6) {
      throw ServerException('Password must be at least 6 characters.');
    }

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('changeUserPassword');
      await callable.call<Map<String, dynamic>>({
        'uid': uid,
        'newPassword': newPassword,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ServerException(e.message ?? 'Failed to change password.');
    } catch (e) {
      throw ServerException(
        'Failed to change password. Ensure the changeUserPassword Cloud Function is deployed. ($e)',
      );
    }
  }

  @override
  Future<List<RoleModel>> getAllRoles() async {
    try {
      final snapshot = await firestore.collection('roles').get();
      if (snapshot.docs.isEmpty) {
        await seedDefaultRoles();
        final seededSnapshot = await firestore.collection('roles').get();
        return seededSnapshot.docs
            .map((doc) => RoleModel.fromFirestore(doc))
            .toList();
      }
      return snapshot.docs.map((doc) => RoleModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw ServerException('Failed to fetch roles: $e');
    }
  }

  @override
  Future<RoleModel> createRole(RoleModel role) async {
    try {
      final id = role.id.isNotEmpty
          ? role.id
          : role.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final docRef = firestore.collection('roles').doc(id);

      final existing = await docRef.get();
      if (existing.exists) {
        throw ServerException('A role with this id already exists.');
      }

      final newRole = RoleModel(
        id: docRef.id,
        name: role.name,
        isSystem: false,
        permissions: role.permissions,
        createdAt: DateTime.now(),
      );
      await docRef.set(newRole.toFirestore());
      return newRole;
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to create role: $e');
    }
  }

  @override
  Future<void> updateRole(RoleModel role) async {
    try {
      final doc = await firestore.collection('roles').doc(role.id).get();
      if (doc.exists && (doc.data()?['isSystem'] ?? false)) {
        // System roles: allow permission tweaks only for non-core flags
        // Super Admin / Admin system roles stay locked for safety.
        if (role.id == 'super_admin' || role.id == 'admin') {
          throw ServerException('Core system roles cannot be modified.');
        }
      }
      await firestore.collection('roles').doc(role.id).update({
        'name': role.name,
        'permissions':
            role.permissions.map((p) => p.toPermissionString()).toList(),
      });
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to update role: $e');
    }
  }

  @override
  Future<void> deleteRole(String roleId) async {
    try {
      final doc = await firestore.collection('roles').doc(roleId).get();
      if (!doc.exists) {
        throw ServerException('Role not found.');
      }
      if (doc.data()?['isSystem'] ?? false) {
        throw ServerException('System roles cannot be deleted.');
      }

      // Block delete if any user still has this role
      final usersWithRole = await firestore
          .collection('users')
          .where('roleId', isEqualTo: roleId)
          .limit(1)
          .get();
      if (usersWithRole.docs.isNotEmpty) {
        throw ServerException(
          'Cannot delete a role that is still assigned to users.',
        );
      }

      await firestore.collection('roles').doc(roleId).delete();
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException('Failed to delete role: $e');
    }
  }

  @override
  Future<void> seedDefaultRoles() async {
    try {
      final batch = firestore.batch();
      final allPermissions = AppPermission.values;

      final superAdminRef = firestore.collection('roles').doc('super_admin');
      batch.set(superAdminRef, {
        'name': 'Super Admin',
        'isSystem': true,
        'permissions':
            allPermissions.map((p) => p.toPermissionString()).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final adminRef = firestore.collection('roles').doc('admin');
      final adminPermissions = allPermissions
          .where((p) => p != AppPermission.manageRoles)
          .map((p) => p.toPermissionString())
          .toList();
      batch.set(adminRef, {
        'name': 'Admin',
        'isSystem': true,
        'permissions': adminPermissions,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final coordinatorRef = firestore.collection('roles').doc('coordinator');
      batch.set(coordinatorRef, {
        'name': 'Coordinator',
        'isSystem': true,
        'permissions': [
          AppPermission.manageVehicles.toPermissionString(),
          AppPermission.manageEmployees.toPermissionString(),
          AppPermission.manageCustomers.toPermissionString(),
          AppPermission.manageCompanies.toPermissionString(),
          AppPermission.viewActivityLogs.toPermissionString(),
        ],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Driver: view-only / evaluation access (not a core system lock beyond seed)
      final driverRef = firestore.collection('roles').doc('driver');
      batch.set(driverRef, {
        'name': 'Driver',
        'isSystem': true,
        'permissions': <String>[
          AppPermission.manageEvaluations.toPermissionString(),
        ],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final officeStaffRef = firestore.collection('roles').doc('office_staff');
      batch.set(officeStaffRef, {
        'name': 'Office Staff',
        'isSystem': true,
        'permissions': [
          AppPermission.manageInvoices.toPermissionString(),
          AppPermission.manageCustomers.toPermissionString(),
          AppPermission.manageCompanies.toPermissionString(),
          AppPermission.viewMasterData.toPermissionString(),
        ],
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      throw ServerException('Failed to seed default roles: $e');
    }
  }
}
