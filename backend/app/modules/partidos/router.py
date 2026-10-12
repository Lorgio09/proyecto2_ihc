from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.connection import get_db
from app.database.models import Usuario
from app.modules.auth.service import current_user
from app.modules.partidos.schemas import MatchData, MatchResponse, MatchUpdate
from app.modules.partidos.service import (
    create_match,
    delete_match,
    find_match,
    list_matches,
    update_match,
    complete_team,
)


router = APIRouter(prefix="/api/partidos", tags=["Partidos"])


def not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Partido no encontrado",
    )


@router.post("", response_model=MatchResponse, status_code=status.HTTP_201_CREATED)
def create(
    data: MatchData,
    db: Session = Depends(get_db),
    user: Usuario = Depends(current_user),
):
    return create_match(data, user, db)


@router.get("", response_model=list[MatchResponse])
def list_all(
    db: Session = Depends(get_db),
    user: Usuario = Depends(current_user),
):
    return list_matches(user, db)


@router.get("/{match_id}", response_model=MatchResponse)
def get(
    match_id: int,
    db: Session = Depends(get_db),
    user: Usuario = Depends(current_user),
):
    match = find_match(match_id, user, db)
    if not match:
        raise not_found()
    return match


@router.put("/{match_id}", response_model=MatchResponse)
def update(
    match_id: int,
    data: MatchUpdate,
    db: Session = Depends(get_db),
    user: Usuario = Depends(current_user),
):
    match = find_match(match_id, user, db)
    if not match:
        raise not_found()
    return update_match(match, data, db)


@router.delete("/{match_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete(
    match_id: int,
    db: Session = Depends(get_db),
    user: Usuario = Depends(current_user),
):
    match = find_match(match_id, user, db)
    if not match:
        raise not_found()
    delete_match(match, db)


@router.patch("/{match_id}/completar", response_model=MatchResponse)
def completar_equipo(
    match_id: int,
    db: Session = Depends(get_db),
    user: Usuario = Depends(current_user),
):
    match = find_match(match_id, user, db)
    if not match:
        raise not_found()
    try:
        return complete_team(match, db)

    except ValueError as error:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(error),
        )