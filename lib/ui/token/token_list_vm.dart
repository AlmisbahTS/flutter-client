import 'dart:async';
import 'package:invoiceninja_flutter/data/models/token_model.dart';
import 'package:invoiceninja_flutter/ui/app/entities/entity_actions_dialog.dart';
import 'package:invoiceninja_flutter/ui/app/tables/entity_list.dart';
import 'package:invoiceninja_flutter/ui/token/token_list_item.dart';
import 'package:invoiceninja_flutter/ui/token/token_presenter.dart';
import 'package:redux/redux.dart';
import 'package:invoiceninja_flutter/redux/app/app_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:built_collection/built_collection.dart';
import 'package:invoiceninja_flutter/redux/ui/list_ui_state.dart';
import 'package:invoiceninja_flutter/utils/completers.dart';
import 'package:invoiceninja_flutter/utils/localization.dart';
import 'package:invoiceninja_flutter/redux/token/token_selectors.dart';
import 'package:invoiceninja_flutter/data/models/models.dart';
import 'package:invoiceninja_flutter/redux/app/app_state.dart';
import 'package:invoiceninja_flutter/redux/token/token_actions.dart';
import 'package:invoiceninja_flutter/utils/platforms.dart';

class TokenListBuilder extends StatelessWidget {
  const TokenListBuilder({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, TokenListVM>(
      converter: TokenListVM.fromStore,
      builder: (context, viewModel) {
        return EntityList(
            isLoaded: viewModel.isLoaded,
            entityType: EntityType.token,
            presenter: TokenPresenter(),
            state: viewModel.state,
            entityList: viewModel.tokenList,
            onEntityTap: viewModel.onTokenTap,
            tableColumns: viewModel.tableColumns,
            onRefreshed: viewModel.onRefreshed,
            onClearEntityFilterPressed: viewModel.onClearEntityFilterPressed,
            onViewEntityFilterPressed: viewModel.onViewEntityFilterPressed,
            onSortColumn: viewModel.onSortColumn,
            itemBuilder: (BuildContext context, index) {
              final state = viewModel.state;
              final tokenId = viewModel.tokenList[index];
              final token = viewModel.tokenMap[tokenId];
              final listState = state.getListState(EntityType.token);
              final isInMultiselect = listState.isInMultiselect();

              return TokenListItem(
                user: viewModel.state.user,
                filter: viewModel.filter,
                token: token,
                onEntityAction: (EntityAction action) {
                  if (action == EntityAction.more) {
                    showEntityActionsDialog(
                      entities: [token],
                      context: context,
                    );
                  } else {
                    handleTokenAction(context, [token], action);
                  }
                },
                onTap: () => viewModel.onTokenTap(context, token),
                onLongPress: () async {
                  final longPressIsSelection =
                      state.prefState.longPressSelectionIsDefault ?? true;
                  if (longPressIsSelection && !isInMultiselect) {
                    handleTokenAction(
                        context, [token], EntityAction.toggleMultiselect);
                  } else {
                    showEntityActionsDialog(
                      entities: [token],
                      context: context,
                    );
                  }
                },
                isChecked: isInMultiselect && listState.isSelected(token.id),
              );
            });
      },
    );
  }
}

class TokenListVM {
  TokenListVM({
    @required this.state,
    @required this.userCompany,
    @required this.tokenList,
    @required this.tokenMap,
    @required this.filter,
    @required this.isLoading,
    @required this.isLoaded,
    @required this.onTokenTap,
    @required this.listState,
    @required this.onRefreshed,
    @required this.onEntityAction,
    @required this.tableColumns,
    @required this.onClearEntityFilterPressed,
    @required this.onViewEntityFilterPressed,
    @required this.onSortColumn,
  });

  static TokenListVM fromStore(Store<AppState> store) {
    Future<Null> _handleRefresh(BuildContext context) {
      if (store.state.isLoading) {
        return Future<Null>(null);
      }
      final completer = snackBarCompleter<Null>(
          context, AppLocalization.of(context).refreshComplete);
      store.dispatch(LoadTokens(completer: completer, force: true));
      return completer.future;
    }

    final state = store.state;

    return TokenListVM(
      state: state,
      userCompany: state.userCompany,
      listState: state.tokenListState,
      tokenList: memoizedFilteredTokenList(
          state.tokenState.map, state.tokenState.list, state.tokenListState),
      tokenMap: state.tokenState.map,
      isLoading: state.isLoading,
      isLoaded: state.tokenState.isLoaded,
      filter: state.tokenUIState.listUIState.filter,
      onClearEntityFilterPressed: () => store.dispatch(ClearEntityFilter()),
      onViewEntityFilterPressed: (BuildContext context) => viewEntityById(
          context: context,
          entityId: state.tokenListState.filterEntityId,
          entityType: state.tokenListState.filterEntityType),
      onTokenTap: (context, token) {
        if (store.state.tokenListState.isInMultiselect()) {
          handleTokenAction(context, [token], EntityAction.toggleMultiselect);
        } else if (isDesktop(context) && state.uiState.isEditing) {
          viewEntity(context: context, entity: token);
        } else if (isDesktop(context) &&
            state.tokenUIState.selectedId == token.id) {
          editEntity(context: context, entity: token);
        } else {
          viewEntity(context: context, entity: token);
        }
      },
      onEntityAction: (BuildContext context, List<BaseEntity> tokens,
              EntityAction action) =>
          handleTokenAction(context, tokens, action),
      onRefreshed: (context) => _handleRefresh(context),
      tableColumns:
          state.userCompany.settings.getTableColumns(EntityType.token) ??
              TokenPresenter.getAllTableFields(state.userCompany),
      onSortColumn: (field) => store.dispatch(SortTokens(field)),
    );
  }

  final AppState state;
  final UserCompanyEntity userCompany;
  final List<String> tokenList;
  final BuiltMap<String, TokenEntity> tokenMap;
  final ListUIState listState;
  final String filter;
  final bool isLoading;
  final bool isLoaded;
  final Function(BuildContext, BaseEntity) onTokenTap;
  final Function(BuildContext) onRefreshed;
  final Function(BuildContext, List<BaseEntity>, EntityAction) onEntityAction;
  final Function onClearEntityFilterPressed;
  final Function(BuildContext) onViewEntityFilterPressed;
  final List<String> tableColumns;
  final Function(String) onSortColumn;
}